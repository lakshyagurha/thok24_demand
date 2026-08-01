-- Rollback for 20260731000002_category_tree_seed.sql.
--
-- Apply AFTER 20260731000003_..._down.sql (products must be back on their original
-- categories before the shelves they were moved to can be removed).
--
-- Restores the 12 original category rows verbatim from the snapshot taken by the
-- forward migration, then deletes only the rows that migration inserted -- matched by
-- slug, so a row someone added by hand afterwards is left alone.

begin;

-- Fail rather than half-restore if the snapshot is missing.
do $$
begin
  if not exists (select 1 from private.category_migration_backup) then
    raise exception
      'private.category_migration_backup is empty -- cannot restore original category names';
  end if;
end;
$$;

-- Products must already be back on their original categories, or deleting the new
-- shelves would fail on the FK (which is the desired outcome, but a clear message
-- beats a constraint-violation stack trace).
do $$
declare n int;
begin
  select count(*) into n
    from public.products p
    join public.main_category m on m.id = p.main_category_id
   where m.slug in (
     'oil-ghee-masala','salt-sugar-jaggery','sauces-spreads','chips-namkeen',
     'biscuits-bakery','cold-drinks-juices','cleaning-detergent','pooja-needs',
     'disposables-foil','pest-freshener','paper-stationery','bath-body','hair-care',
     'oral-care','skin-face-care','shaving-grooming','feminine-hygiene',
     'baby-food-care','health-nutrition','first-aid-medicine','pet-care',
     'bulbs-batteries','kitchen-appliances','home-improvement','uncategorised');
  if n > 0 then
    raise exception
      '% products still sit on shelves created by this migration. Apply 20260731000003_..._down.sql first.',
      n;
  end if;
end;
$$;

-- 1. Restore the 12 original rows (name, name_hi, name_hn, image) and clear the tree
--    columns this migration set. Uses the most recent snapshot.
with snapshot as (
  select main_category
    from private.category_migration_backup
   order by taken_at desc
   limit 1
),
original as (
  select (e ->> 'id')::bigint   as id,
         e ->> 'name'           as name,
         e ->> 'name_hi'        as name_hi,
         e ->> 'name_hn'        as name_hn,
         e ->> 'image'          as image
    from snapshot, jsonb_array_elements(snapshot.main_category) e
)
update public.main_category m set
  name      = o.name,
  name_hi   = o.name_hi,
  name_hn   = o.name_hn,
  image     = o.image,
  parent_id = null,
  slug      = null,
  level     = 2,          -- ...01_down drops the column entirely; this is a safe interim
  icon_url  = null,
  sort_order= 0,
  is_active = true
from original o
where m.id = o.id;

-- The root check is NOT VALID again from here on: the restored rows are level 2 with no
-- parent, which is exactly the state ...01 tolerated via NOT VALID. Dropping and
-- re-adding it keeps that honest instead of leaving a validated constraint that the data
-- now violates.
alter table public.main_category drop constraint if exists main_category_root_ck;
alter table public.main_category
  add constraint main_category_root_ck
    check ((level = 1 and parent_id is null) or (level > 1 and parent_id is not null))
    not valid;

-- 2. Remove only what this migration inserted.
delete from public.main_category
 where slug in (
   'grocery-kitchen','snacks-drinks','household-essentials','beauty-personal-care',
   'baby-wellness','home-electricals','unfiled',
   'oil-ghee-masala','salt-sugar-jaggery','sauces-spreads','chips-namkeen',
   'biscuits-bakery','cold-drinks-juices','cleaning-detergent','pooja-needs',
   'disposables-foil','pest-freshener','paper-stationery','bath-body','hair-care',
   'oral-care','skin-face-care','shaving-grooming','feminine-hygiene',
   'baby-food-care','health-nutrition','first-aid-medicine','pet-care',
   'bulbs-batteries','kitchen-appliances','home-improvement','uncategorised');

do $$
declare n int;
begin
  select count(*) into n from public.main_category;
  if n <> 12 then
    raise exception 'expected 12 categories after rollback, found %', n;
  end if;
end;
$$;

commit;
