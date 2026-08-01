-- Phase 4 of the category taxonomy work. See docs/category-system-plan.md §5.
--
-- One call returns the whole browsable tree. Today the consumer app fetches the flat
-- category list and then counts products per category by opening each one, so the
-- Category tab cannot tell a stocked shelf from an empty one without N round trips --
-- which is precisely why 8 empty categories currently render as normal, tappable tiles
-- that lead to a blank screen.
--
-- `product_count` is included per node so the app can render the "Coming soon" state
-- from the same payload, with no second query.
--
-- All three name variants ship in one payload. The app localises at render time via
-- Category.localizedName(), so switching language costs zero requests -- the same
-- reasoning already documented in categoryScreen.dart.

-- ---------------------------------------------------------------------------
-- 1. Health view: what the admin needs to see, and the dry-run tool asserts on
-- ---------------------------------------------------------------------------

create or replace view public.v_category_health as
with direct as (
  select main_category_id as id, count(*) filter (where is_active) as active_products
    from public.products
   group by main_category_id
)
select
  c.id,
  c.slug,
  c.name,
  c.level,
  c.parent_id,
  p.name                                          as parent_name,
  c.is_active,
  c.sort_order,
  coalesce(d.active_products, 0)                  as active_products,
  exists (select 1 from public.main_category k where k.parent_id = c.id) as has_children,
  c.icon_url is null or c.icon_url = ''           as missing_icon,
  length(c.name) > 22                             as name_too_long,
  length(c.name) - length(replace(c.name, '&', '')) > 1 as too_many_ampersands,
  coalesce(c.name_hi, '') = ''                    as missing_hindi,
  coalesce(c.name_hn, '') = ''                    as missing_hinglish,
  -- A shelf holding both products and child shelves is the one thing the level>=2
  -- trigger deliberately does not block, because blocking it would deadlock adding an
  -- L3 under a stocked shelf. It is reported here instead.
  coalesce(d.active_products, 0) > 0
    and exists (select 1 from public.main_category k where k.parent_id = c.id)
                                                  as products_and_children
from public.main_category c
left join direct d on d.id = c.id
left join public.main_category p on p.id = c.parent_id;

comment on view public.v_category_health is
  'Per-category data-quality report: stock, leaf-ness, naming rule violations. Read by '
  'the admin category screen and by supabase/tools/category_backfill.py.';

-- The view reads main_category and products, both of which have a select-all policy,
-- so exposing it adds no access. `security_invoker` keeps it that way: the view is
-- evaluated with the caller's own permissions rather than the definer's, so it can
-- never become a way around a future restriction on either base table.
alter view public.v_category_health set (security_invoker = true);
grant select on public.v_category_health to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. The tree
-- ---------------------------------------------------------------------------

create or replace function public.category_tree()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with counts as (
    select main_category_id as id, count(*)::int as n
      from public.products
     where is_active
     group by main_category_id
  ),

  -- Built bottom-up, one CTE per level, rather than with a recursive CTE. The depth is
  -- capped at 3 by a check constraint, so recursion buys nothing here, and this form
  -- produces the nested shape directly. Adding L3 nodes later needs no change: the
  -- level-3 CTE is already here and simply returns nothing today.
  l3 as (
    select c.parent_id,
           jsonb_agg(
             jsonb_build_object(
               'id', c.id, 'slug', c.slug, 'level', c.level, 'parent_id', c.parent_id,
               'name', c.name, 'name_hi', c.name_hi, 'name_hn', c.name_hn,
               'icon_url', coalesce(c.icon_url, c.image),
               'sort_order', c.sort_order, 'is_active', c.is_active,
               'product_count', coalesce(n.n, 0),
               'children', '[]'::jsonb
             ) order by c.sort_order, c.name
           ) as children,
           sum(coalesce(n.n, 0))::int as subtree_count
      from public.main_category c
      left join counts n on n.id = c.id
     where c.level = 3 and c.is_active
     group by c.parent_id
  ),

  l2 as (
    select c.parent_id,
           jsonb_agg(
             jsonb_build_object(
               'id', c.id, 'slug', c.slug, 'level', c.level, 'parent_id', c.parent_id,
               'name', c.name, 'name_hi', c.name_hi, 'name_hn', c.name_hn,
               'icon_url', coalesce(c.icon_url, c.image),
               'sort_order', c.sort_order, 'is_active', c.is_active,
               -- Own products plus anything on a child shelf, so a stocked L3 keeps its
               -- L2 parent out of the "Coming soon" state.
               'product_count', coalesce(n.n, 0) + coalesce(k.subtree_count, 0),
               'children', coalesce(k.children, '[]'::jsonb)
             ) order by c.sort_order, c.name
           ) as children,
           sum(coalesce(n.n, 0) + coalesce(k.subtree_count, 0))::int as subtree_count
      from public.main_category c
      left join counts n on n.id = c.id
      left join l3     k on k.parent_id = c.id
     where c.level = 2 and c.is_active
     group by c.parent_id
  )

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id, 'slug', c.slug, 'level', c.level, 'parent_id', null,
        'name', c.name, 'name_hi', c.name_hi, 'name_hn', c.name_hn,
        'icon_url', coalesce(c.icon_url, c.image),
        'sort_order', c.sort_order, 'is_active', c.is_active,
        'product_count', coalesce(k.subtree_count, 0),
        'children', coalesce(k.children, '[]'::jsonb)
      ) order by c.sort_order, c.name
    ),
    '[]'::jsonb)
    from public.main_category c
    left join l2 k on k.parent_id = c.id
   where c.level = 1 and c.is_active;
$$;

comment on function public.category_tree() is
  'The full active category tree as nested JSON, with an active product count per node. '
  'One round trip replaces the flat category list plus a per-category product fetch. '
  'Inactive nodes are excluded, so is_active is the single visibility switch.';

grant execute on function public.category_tree() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Shape assertion
-- ---------------------------------------------------------------------------

do $$
declare
  tree jsonb;
  n_roots int;
  n_shelves int;
begin
  tree := public.category_tree();

  select jsonb_array_length(tree) into n_roots;
  if n_roots <> 6 then
    raise exception 'category_tree() returned % umbrellas, expected 6', n_roots;
  end if;

  select count(*) into n_shelves
    from jsonb_array_elements(tree) r,
         jsonb_array_elements(r -> 'children') s;
  if n_shelves <> 34 then
    raise exception 'category_tree() returned % shelves, expected 34', n_shelves;
  end if;

  -- The retired rows and the Unfiled/Uncategorised staging pair must not leak.
  if exists (
    select 1
      from jsonb_array_elements(tree) r,
           jsonb_array_elements(r -> 'children') s
     where s ->> 'slug' in ('uncategorised', 'retired-electronics-appliances',
                            'retired-packaged-food')
  ) then
    raise exception 'category_tree() exposed a retired or staging category';
  end if;

  raise notice 'category_tree(): % umbrellas, % shelves, % bytes',
    n_roots, n_shelves, length(tree::text);
end;
$$;
