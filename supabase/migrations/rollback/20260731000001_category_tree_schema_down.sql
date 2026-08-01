-- Rollback for 20260731000001_category_tree_schema.sql.
--
-- Apply the rollbacks in reverse order: ...04_down, ...03_down, ...02_down, then this.
-- Running this while ...02 or ...03 is still applied will fail on the parent_id FK,
-- which is intentional -- it stops a partial rollback from leaving orphaned tree rows.
--
-- This drops columns that ...02 and ...03 populate, so it destroys the tree structure
-- and the is_active flags. It does NOT delete any category or product row; ...02_down
-- and ...03_down handle restoring names and category assignments from
-- private.category_migration_backup.

begin;

-- Fail loudly rather than silently dropping a populated tree: if any category still has
-- a parent, the seed migration has not been rolled back yet.
do $$
begin
  if exists (select 1 from public.main_category where parent_id is not null) then
    raise exception
      'refusing to run: categories still have parents. Apply 20260731000002_..._down.sql first.';
  end if;
end;
$$;

drop trigger if exists products_category_level_check on public.products;
drop function if exists private.check_product_category();

drop trigger if exists main_category_depth_check on public.main_category;
drop function if exists private.check_category_depth();

drop index if exists public.products_active_category_idx;
alter table public.products drop column if exists is_active;

drop index if exists public.main_category_browse_idx;
drop index if exists public.main_category_parent_idx;
drop index if exists public.main_category_name_key;
drop index if exists public.main_category_slug_key;

alter table public.main_category
  drop constraint if exists main_category_root_ck,
  drop constraint if exists main_category_selfref_ck,
  drop constraint if exists main_category_level_ck,
  drop constraint if exists main_category_parent_fk;

-- Restore the original nullability. `name` was nullable before this work.
alter table public.main_category alter column name drop not null;

alter table public.main_category
  drop column if exists created_at,
  drop column if exists is_active,
  drop column if exists sort_order,
  drop column if exists icon_url,
  drop column if exists level,
  drop column if exists slug,
  drop column if exists parent_id;

commit;
