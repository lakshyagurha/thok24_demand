-- Phase 1 of the category taxonomy work. See docs/category-system-plan.md.
--
-- What is wrong today: `main_category` is a flat list of 12 rows with only
-- (id, name, name_hi, name_hn, image). There is no subcategory table anywhere, so the
-- catalog has exactly one level, and those 12 names are shelf-grade names
-- ("Atta, Rice, Oil & Dals", "Dairy, Bread & Eggs") with no umbrella above them. There
-- is also no way to order categories (every consumer falls back to `order by id`, i.e.
-- insertion order) and no way to hide one -- which is why `homeScreen.dart` hides
-- Electronics by substring-matching its English name in Dart.
--
-- This migration adds the *shape*. It seeds nothing and moves no product: the tree is
-- populated in 20260731000002 and products are remapped in 20260731000003, so each is
-- reviewable on its own.
--
-- One self-referencing table rather than separate categories/subcategories tables:
-- depth becomes data instead of schema (adding an L3 later is an INSERT, not a
-- migration + FK + RLS policy + admin screen), `products.main_category_id` and
-- `banner.category_id` keep the foreign keys they already have, and the existing
-- `main_category_select_all` policy and admin-api allowlist entry keep working untouched.
--
-- Nothing here is destructive. No table is dropped, no row is deleted, and every added
-- column is nullable or defaulted so the statement is instant on the live table.

-- ---------------------------------------------------------------------------
-- 1. The tree columns
-- ---------------------------------------------------------------------------

alter table public.main_category
  add column parent_id  bigint,
  -- Stable, human-readable handle. Nothing routes on it yet (the app has no router --
  -- see the plan's "out of scope"), but it is what prevents duplicate categories and
  -- what a deep link would address later, so it ships now rather than as a second
  -- migration against a table that by then has real references.
  add column slug       text,
  add column level      smallint    not null default 2,
  add column icon_url   text,
  add column sort_order integer     not null default 0,
  add column is_active  boolean     not null default true,
  add column created_at timestamptz not null default now();

comment on column public.main_category.level is
  '1 = umbrella (L1), 2 = shelf (L2), 3 = sub-shelf (L3). Products attach at >= 2.';
comment on column public.main_category.is_active is
  'Soft visibility. Replaces the hardcoded name filter in homeScreen.dart. Retired '
  'categories are deactivated, never deleted -- deleting one cascades to its products.';

-- restrict, not cascade. `products.main_category_id` already cascades on delete, so a
-- cascading parent link would turn "delete an umbrella" into "delete every product
-- underneath it" in one statement. Nothing in this plan deletes a category; this is the
-- guard for whoever comes next.
alter table public.main_category
  add constraint main_category_parent_fk
    foreign key (parent_id) references public.main_category (id)
    on delete restrict on update cascade;

-- ---------------------------------------------------------------------------
-- 2. Integrity
-- ---------------------------------------------------------------------------

-- `name` was nullable with no uniqueness, so nothing stopped a second "Frozen Food" or
-- a category with no name at all. All 12 live rows have distinct non-null names, so
-- both of these are satisfiable today.
alter table public.main_category alter column name set not null;

alter table public.main_category
  add constraint main_category_level_ck
    check (level between 1 and 3),
  add constraint main_category_selfref_ck
    check (parent_id is distinct from id);

-- NOT VALID on purpose. The 12 existing rows are all parentless right now, so this
-- would fail outright if validated here. NOT VALID still enforces the rule on every
-- insert and update from this moment on; migration ...02 assigns the parents and then
-- runs VALIDATE CONSTRAINT to prove the pre-existing rows conform too.
alter table public.main_category
  add constraint main_category_root_ck
    check ((level = 1 and parent_id is null) or (level > 1 and parent_id is not null))
    not valid;

create unique index main_category_slug_key on public.main_category (slug);
create unique index main_category_name_key on public.main_category (lower(name));

-- ---------------------------------------------------------------------------
-- 3. Indexes for the browse path
-- ---------------------------------------------------------------------------

create index main_category_parent_idx on public.main_category (parent_id);

-- The only hot read in the whole feature: "active children of X, in display order."
-- Partial on is_active because inactive rows are never browsed, only administered.
create index main_category_browse_idx
  on public.main_category (parent_id, sort_order)
  where is_active;

-- ---------------------------------------------------------------------------
-- 4. Depth consistency
-- ---------------------------------------------------------------------------

-- A child sits exactly one level below its parent. This single rule also makes cycles
-- structurally impossible: closing a loop would require `level` to increase without
-- bound around it. That is why there is no separate recursive cycle check here.
--
-- SECURITY DEFINER in `private`, matching `private.handle_new_user`: the function reads
-- main_category, and pinning it this way keeps the behaviour identical regardless of
-- which role performs the write (admin-api writes as service_role, migrations as
-- postgres). It reads one world-readable row and raises; it confers no privilege.
create function private.check_category_depth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_level smallint;
begin
  if new.parent_id is null then
    if new.level <> 1 then
      raise exception 'category "%" has no parent so it must be level 1, not %',
        new.name, new.level;
    end if;
    return new;
  end if;

  select level into parent_level
    from public.main_category
   where id = new.parent_id;

  if parent_level is null then
    raise exception 'category "%" references parent id % which does not exist',
      new.name, new.parent_id;
  end if;

  if new.level <> parent_level + 1 then
    raise exception 'category "%" is level % but its parent is level % (must be %)',
      new.name, new.level, parent_level, parent_level + 1;
  end if;

  return new;
end;
$$;

create trigger main_category_depth_check
  before insert or update of parent_id, level on public.main_category
  for each row execute function private.check_category_depth();

-- ---------------------------------------------------------------------------
-- 5. Products may never hang off an umbrella
-- ---------------------------------------------------------------------------

-- Level >= 2 is the hard rule. Leaf-ness (only nodes with no children may hold
-- products) is deliberately NOT enforced here: it would deadlock the day someone adds
-- an L3 under a shelf that already has stock, forcing an ordering dance in the admin
-- for no safety gain. The admin picker only offers leaves, and `v_category_health`
-- (migration ...04) reports any shelf that ends up holding both products and children.
create function private.check_product_category()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  lvl smallint;
begin
  select level into lvl
    from public.main_category
   where id = new.main_category_id;

  if lvl is null then
    raise exception 'product "%" references category id % which does not exist',
      new.name, new.main_category_id;
  end if;

  if lvl < 2 then
    raise exception
      'product "%" must be filed under a subcategory (level >= 2), not umbrella id %',
      new.name, new.main_category_id;
  end if;

  return new;
end;
$$;

create trigger products_category_level_check
  before insert or update of main_category_id on public.products
  for each row execute function private.check_product_category();

-- ---------------------------------------------------------------------------
-- 6. Soft-withdraw a SKU
-- ---------------------------------------------------------------------------

-- There was no way to stop selling something short of deleting the row, and
-- `product_variants`, `product_images`, `product_info`, `product_highlights` and
-- `product_aliases` all cascade from it -- so withdrawing one SKU destroyed its
-- hand-built Hindi voice vocabulary along with it. Migration ...03 uses this to retire
-- the smartwatch and the Bluetooth speaker without losing either.
alter table public.products
  add column is_active boolean not null default true;

comment on column public.products.is_active is
  'Soft withdrawal. Catalog reads filter on this; deleting a product would cascade to '
  'its variants, images, info, highlights and voice aliases.';

create index products_active_category_idx
  on public.products (main_category_id)
  where is_active;
