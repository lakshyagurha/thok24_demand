-- Tranche B: close the four server-side holes the consumer-app audit found.
--
-- Each block below is independent; read them separately.
--
--   1. cart_items had no uniqueness, so a double-tap created duplicate rows and then
--      permanently broke add-to-cart for that variant.
--   2. Stock was never checked or decremented anywhere on the server, so overselling was
--      structural rather than a race.
--   3. place-order had no idempotency, so a dropped HTTP response produced a second real
--      order when the customer retried.
--   4. Coupons had no redemption limit of any kind.
--
-- Nothing here drops or rewrites existing data. The two backfills are no-ops on the
-- current dataset (verified: zero duplicate cart rows) and exist so the migration is
-- safe to replay against a database that has drifted.

-- ---------------------------------------------------------------------------
-- 1. cart_items uniqueness + an atomic add
-- ---------------------------------------------------------------------------

-- Collapse any duplicates before the unique index goes on, summing their quantities so
-- no one silently loses items from their cart. No-op today.
with ranked as (
  select id,
         first_value(id) over w as keep_id,
         sum(quantity) over w    as total_quantity
  from public.cart_items
  window w as (
    partition by user_id, product_id, variant_id
    order by id
    rows between unbounded preceding and unbounded following
  )
)
update public.cart_items c
   set quantity = r.total_quantity
  from ranked r
 where c.id = r.keep_id
   and c.id = r.id
   and c.quantity <> r.total_quantity;

delete from public.cart_items c
 where exists (
   select 1 from public.cart_items other
    where other.user_id = c.user_id
      and other.product_id = c.product_id
      and other.variant_id is not distinct from c.variant_id
      and other.id < c.id
 );

-- NULLS NOT DISTINCT (PG15+) matters: variant_id is nullable, and under the default
-- NULLS DISTINCT two rows with a null variant would both be allowed, which is exactly
-- the duplicate this index exists to prevent.
create unique index if not exists cart_items_user_product_variant_key
  on public.cart_items (user_id, product_id, variant_id) nulls not distinct;

-- Read-then-write in the client could interleave. This does it in one statement.
--
-- SECURITY INVOKER on purpose: RLS still applies, so the INSERT policy's WITH CHECK
-- (user_id = auth.uid()) remains the thing that stops a caller writing into someone
-- else's cart. The function adds atomicity, not privilege.
create or replace function public.cart_add(
  p_product_id bigint,
  p_variant_id bigint default null,
  p_quantity   int     default 1,
  p_image_url  text    default ''
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be a positive integer';
  end if;

  insert into public.cart_items (user_id, product_id, variant_id, quantity, image_url)
  values (auth.uid(), p_product_id, p_variant_id, p_quantity, p_image_url)
  on conflict (user_id, product_id, variant_id)
  do update set quantity = public.cart_items.quantity + excluded.quantity;
end;
$$;

revoke all on function public.cart_add(bigint, bigint, int, text) from public;
-- `revoke ... from public` does NOT remove the explicit EXECUTE that Supabase's default
-- privileges hand to anon on every new function in this schema, so revoke it by name.
-- (Verified: without this line the ACL comes back as `anon=X/postgres`.) An anonymous
-- caller would fail anyway — auth.uid() is null, so the insert violates both NOT NULL and
-- the RLS WITH CHECK — but there is no reason to leave it callable.
revoke execute on function public.cart_add(bigint, bigint, int, text) from anon;
grant execute on function public.cart_add(bigint, bigint, int, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Stock reservation
-- ---------------------------------------------------------------------------
--
-- The whole function body is one transaction, so a raise anywhere rolls back every
-- decrement it already made -- an order can never partially consume stock.
--
-- `stock >= quantity` lives in the UPDATE's WHERE clause rather than in a separate
-- SELECT, so two concurrent orders for the last unit cannot both pass the check: the
-- second one matches zero rows and raises.
--
-- service_role only. This is called by place-order, never by a client.

create or replace function public.reserve_stock(p_items jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  item    record;
  touched int;
begin
  for item in
    select (e->>'variant_id')::bigint as variant_id,
           (e->>'quantity')::int      as quantity
      from jsonb_array_elements(p_items) e
     where e->>'variant_id' is not null
     order by 1  -- stable lock order, so concurrent orders cannot deadlock each other
  loop
    update public.product_variants v
       set stock = v.stock - item.quantity
     where v.id = item.variant_id
       and v.stock >= item.quantity;

    get diagnostics touched = row_count;
    if touched = 0 then
      raise exception 'INSUFFICIENT_STOCK:%', item.variant_id
        using errcode = 'P0001';
    end if;
  end loop;
end;
$$;

revoke all on function public.reserve_stock(jsonb) from public;
revoke all on function public.reserve_stock(jsonb) from anon;
revoke all on function public.reserve_stock(jsonb) from authenticated;
grant execute on function public.reserve_stock(jsonb) to service_role;

-- Compensating action for the narrow window where stock is reserved but the order rows
-- then fail to write. Same service_role-only grant.
create or replace function public.release_stock(p_items jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  item record;
begin
  for item in
    select (e->>'variant_id')::bigint as variant_id,
           (e->>'quantity')::int      as quantity
      from jsonb_array_elements(p_items) e
     where e->>'variant_id' is not null
     order by 1
  loop
    update public.product_variants v
       set stock = v.stock + item.quantity
     where v.id = item.variant_id;
  end loop;
end;
$$;

revoke all on function public.release_stock(jsonb) from public;
revoke all on function public.release_stock(jsonb) from anon;
revoke all on function public.release_stock(jsonb) from authenticated;
grant execute on function public.release_stock(jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Order idempotency
-- ---------------------------------------------------------------------------
--
-- The client generates one key per checkout attempt and reuses it on retry. A retry
-- after a dropped response then returns the original order instead of creating a second.
-- Partial index so the millions of historical nulls cost nothing and pre-existing rows
-- do not collide with each other.

alter table public.orders
  add column if not exists idempotency_key uuid;

create unique index if not exists orders_user_idempotency_key
  on public.orders (user_id, idempotency_key)
  where idempotency_key is not null;

-- ---------------------------------------------------------------------------
-- 4. Coupon redemption limits
-- ---------------------------------------------------------------------------
--
-- Both limits are nullable and null means unlimited, which preserves the current
-- behaviour of every existing coupon row until someone deliberately sets a limit.

alter table public.coupon
  add column if not exists usage_limit    integer,
  add column if not exists per_user_limit integer;

comment on column public.coupon.usage_limit is
  'Total redemptions allowed across all users. NULL = unlimited.';
comment on column public.coupon.per_user_limit is
  'Redemptions allowed per user. NULL = unlimited.';

create table if not exists public.coupon_redemptions (
  id          bigint generated by default as identity primary key,
  coupon_id   bigint      not null references public.coupon (id)   on delete cascade,
  user_id     uuid        not null references auth.users (id)      on delete cascade,
  order_id    bigint      not null references public.orders (id)   on delete cascade,
  redeemed_at timestamptz not null default now()
);

create index if not exists coupon_redemptions_coupon_id_idx
  on public.coupon_redemptions (coupon_id);
create index if not exists coupon_redemptions_user_id_idx
  on public.coupon_redemptions (user_id);

-- One redemption row per order, so a retry cannot double-count against a limit.
create unique index if not exists coupon_redemptions_order_id_key
  on public.coupon_redemptions (order_id);

alter table public.coupon_redemptions enable row level security;

-- Same shape as `orders`: readable by its owner, writable only by the Edge Function
-- through the service role. No INSERT/UPDATE/DELETE policy is defined for clients, so
-- a redemption cannot be forged or deleted to reset a limit.
drop policy if exists "coupon_redemptions_select_own" on public.coupon_redemptions;
create policy "coupon_redemptions_select_own"
  on public.coupon_redemptions
  for select
  to authenticated
  using (user_id = (select auth.uid()));

grant select on public.coupon_redemptions to authenticated;
