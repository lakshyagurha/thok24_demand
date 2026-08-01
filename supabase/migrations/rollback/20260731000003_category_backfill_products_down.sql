-- Rollback for 20260731000003_category_backfill_products.sql.
--
-- Apply FIRST, before ...02_down and ...01_down: the shelves those remove cannot be
-- deleted while products still sit on them.
--
-- Restores every product's original main_category_id and is_active from the snapshot
-- taken by 20260731000002. No product is deleted; the two withdrawn SKUs come back
-- active because that is the state the snapshot recorded.

begin;

do $$
begin
  if not exists (select 1 from private.category_migration_backup) then
    raise exception
      'private.category_migration_backup is empty -- cannot restore product categories';
  end if;
end;
$$;

with snapshot as (
  select products
    from private.category_migration_backup
   order by taken_at desc
   limit 1
),
original as (
  select (e ->> 'id')::bigint               as id,
         (e ->> 'main_category_id')::bigint as main_category_id,
         -- `is_active` did not exist when the very first snapshot was taken against a
         -- database where ...01 had not run; treat a null as the column default.
         coalesce((e ->> 'is_active')::boolean, true) as is_active
    from snapshot, jsonb_array_elements(snapshot.products) e
)
update public.products p set
  main_category_id = o.main_category_id,
  is_active        = o.is_active
from original o
where p.id = o.id
  and (p.main_category_id is distinct from o.main_category_id
       or p.is_active is distinct from o.is_active);

do $$
declare n int;
begin
  select count(*) into n from public.products where not is_active;
  if n > 0 then
    raise exception '% products are still withdrawn after rollback', n;
  end if;

  select count(*) into n
    from public.products p
   where not exists (select 1 from public.main_category c where c.id = p.main_category_id);
  if n > 0 then
    raise exception '% products point at a category that no longer exists', n;
  end if;
end;
$$;

commit;
