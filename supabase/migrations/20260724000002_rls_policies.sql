-- DxMart: Row Level Security policies (Phase 2)
--
-- Model: pure ownership. DxMart is consumer-only, so NO policy here distinguishes user
-- types, references a role/account_type column, or gates on wholesale_price.
--
-- Conventions applied throughout, per Supabase guidance:
--   * `TO authenticated` is never used alone -- it is authentication, not authorization.
--     Every policy pairs it with an ownership predicate.
--   * `(select auth.uid())` is wrapped in a subquery so the planner evaluates it once
--     per statement (InitPlan) instead of once per row.
--   * UPDATE policies carry BOTH `using` and `with check`, otherwise a user could
--     reassign a row's user_id to somebody else.
--   * `auth.role()` is never used -- it is deprecated and passes for anonymous sign-ins.
--   * Separate policy per operation, so intent is readable and grants stay minimal.
--
-- Privileges are revoked to zero first and granted back explicitly, so nothing is
-- reachable by accident through Postgres default privileges. RLS decides which ROWS are
-- visible; grants decide whether the table is reachable at all. Both must line up.

-- ---------------------------------------------------------------------------
-- Reset privileges
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;

-- ===========================================================================
-- CATALOG -- world-readable, never client-writable
-- ===========================================================================
-- Writes are absent by design: there is no INSERT/UPDATE/DELETE policy on any catalog
-- table, so no client can modify the catalog regardless of grants. Admin writes go
-- through an Edge Function using the service-role key (Phase 3).

grant select on
  public.district, public.city, public.main_category, public.products,
  public.product_variants, public.product_images, public.product_info,
  public.product_highlights, public.product_aliases, public.banner,
  public.app_settings
to anon, authenticated;

create policy "district_select_all" on public.district
  for select to anon, authenticated using (true);

create policy "city_select_all" on public.city
  for select to anon, authenticated using (true);

create policy "main_category_select_all" on public.main_category
  for select to anon, authenticated using (true);

create policy "products_select_all" on public.products
  for select to anon, authenticated using (true);

create policy "product_variants_select_all" on public.product_variants
  for select to anon, authenticated using (true);

create policy "product_images_select_all" on public.product_images
  for select to anon, authenticated using (true);

create policy "product_info_select_all" on public.product_info
  for select to anon, authenticated using (true);

create policy "product_highlights_select_all" on public.product_highlights
  for select to anon, authenticated using (true);

-- The Hindi/Hinglish voice vocabulary. Readable so the client can resolve spoken
-- product names without a round trip; it contains no user data.
create policy "product_aliases_select_all" on public.product_aliases
  for select to anon, authenticated using (true);

create policy "banner_select_all" on public.banner
  for select to anon, authenticated using (true);

-- Delivery charges, minimum order value, help contact numbers.
create policy "app_settings_select_all" on public.app_settings
  for select to anon, authenticated using (true);

-- Coupons: only ones marked Public are listable. Private codes must NOT be enumerable
-- by clients, so redeeming one has to go through the order-placement Edge Function,
-- which validates the code server-side with the service-role key.
grant select on public.coupon to anon, authenticated;

create policy "coupon_select_public_only" on public.coupon
  for select to anon, authenticated
  using (status = 'Public');

-- ===========================================================================
-- USER-OWNED DATA -- ownership enforced by the database
-- ===========================================================================

-- --- user_profiles -------------------------------------------------------
-- No INSERT policy: rows are created by the private.handle_new_user trigger on signup.
-- No DELETE policy: profiles disappear via ON DELETE CASCADE from auth.users.
grant select, update on public.user_profiles to authenticated;

create policy "user_profiles_select_own" on public.user_profiles
  for select to authenticated
  using ( (select auth.uid()) = id );

create policy "user_profiles_update_own" on public.user_profiles
  for update to authenticated
  using ( (select auth.uid()) = id )
  with check ( (select auth.uid()) = id );

-- --- delivery_address ----------------------------------------------------
grant select, insert, update, delete on public.delivery_address to authenticated;

create policy "delivery_address_select_own" on public.delivery_address
  for select to authenticated
  using ( (select auth.uid()) = user_id );

create policy "delivery_address_insert_own" on public.delivery_address
  for insert to authenticated
  with check ( (select auth.uid()) = user_id );

create policy "delivery_address_update_own" on public.delivery_address
  for update to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );

create policy "delivery_address_delete_own" on public.delivery_address
  for delete to authenticated
  using ( (select auth.uid()) = user_id );

-- --- cart_items ----------------------------------------------------------
grant select, insert, update, delete on public.cart_items to authenticated;

create policy "cart_items_select_own" on public.cart_items
  for select to authenticated
  using ( (select auth.uid()) = user_id );

create policy "cart_items_insert_own" on public.cart_items
  for insert to authenticated
  with check ( (select auth.uid()) = user_id );

create policy "cart_items_update_own" on public.cart_items
  for update to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );

create policy "cart_items_delete_own" on public.cart_items
  for delete to authenticated
  using ( (select auth.uid()) = user_id );

-- --- wishlist ------------------------------------------------------------
-- No UPDATE: a wishlist row is just a (user, product) link. Changing your mind is a
-- delete plus an insert, so there is nothing to update and no policy to get wrong.
grant select, insert, delete on public.wishlist to authenticated;

create policy "wishlist_select_own" on public.wishlist
  for select to authenticated
  using ( (select auth.uid()) = user_id );

create policy "wishlist_insert_own" on public.wishlist
  for insert to authenticated
  with check ( (select auth.uid()) = user_id );

create policy "wishlist_delete_own" on public.wishlist
  for delete to authenticated
  using ( (select auth.uid()) = user_id );

-- --- chat_messages -------------------------------------------------------
-- Append-only: no UPDATE or DELETE policy, so voice-order history cannot be rewritten
-- from a client.
grant select, insert on public.chat_messages to authenticated;

create policy "chat_messages_select_own" on public.chat_messages
  for select to authenticated
  using ( (select auth.uid()) = user_id );

create policy "chat_messages_insert_own" on public.chat_messages
  for insert to authenticated
  with check ( (select auth.uid()) = user_id );

-- --- regular_orders ------------------------------------------------------
-- Read-only from the client. frequency_score is maintained server-side by the
-- order-placement Edge Function; letting a client write it would let them forge the
-- "your usual" suggestions the bot makes.
grant select on public.regular_orders to authenticated;

create policy "regular_orders_select_own" on public.regular_orders
  for select to authenticated
  using ( (select auth.uid()) = user_id );

-- ===========================================================================
-- ORDERS -- readable by their owner, never client-writable
-- ===========================================================================
-- Deliberately NO insert/update/delete policy.
--
-- The current PHP endpoint computes total_amount server-side from the catalog but takes
-- discount_amount, delivery_charge, handling_charge and final_amount straight from the
-- request body, so a client can name its own final price. Granting INSERT here would
-- carry that flaw into the new system and RLS cannot prevent it -- an ownership
-- predicate proves who you are, not what you should be charged.
--
-- Order placement therefore goes through an Edge Function (Phase 3) that recomputes
-- every monetary field from the catalog and validates the coupon server-side.

grant select on public.orders, public.order_items to authenticated;

create policy "orders_select_own" on public.orders
  for select to authenticated
  using ( (select auth.uid()) = user_id );

-- Ownership is inherited from the parent order rather than duplicated onto the line
-- item, so the two can never disagree.
create policy "order_items_select_own" on public.order_items
  for select to authenticated
  using (
    exists (
      select 1
      from public.orders o
      where o.id = order_items.order_id
        and o.user_id = (select auth.uid())
    )
  );

-- ===========================================================================
-- NO CLIENT ACCESS AT ALL
-- ===========================================================================
-- public.delivery_boy holds rider names, mobile numbers and home addresses. It has RLS
-- enabled, zero policies and zero grants, so it is unreachable by anon and
-- authenticated. Only the service-role key (server-side, Phase 3) can read it.
--
-- private.admin_users is in an unexposed schema, additionally has RLS enabled, and is
-- consulted only by the admin Edge Function.
