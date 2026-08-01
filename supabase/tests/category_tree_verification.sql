-- Category taxonomy verification against the REAL live schema.
--
-- Proves the invariants the taxonomy depends on, in the same style and with the same
-- safety guarantee as rls_live_verification.sql in this directory: everything runs
-- inside a transaction that ends in ROLLBACK, so the negative tests below genuinely
-- attempt forbidden writes and leave nothing behind. Safe to run against an
-- environment with real data.
--
-- Requires migrations 20260731000001..04 to be applied.
--
-- Run with:  supabase db query --file supabase/tests/category_tree_verification.sql
--        or: paste into the SQL editor / MCP execute_sql
--
-- Expect 26 rows, all PASS. A FAIL here means either a migration did not land or
-- something has since edited the tree into an invalid state.

BEGIN;

create temp table cat_results(n int, check_name text, expected text, actual text, pass boolean);

do $$
declare
  v text;
  n int;
  umbrella_id bigint;
  shelf_id bigint;
  tree jsonb;
begin
  -- ==========================================================================
  -- Shape
  -- ==========================================================================

  select count(*)::text into v from public.main_category where level = 1 and is_active;
  insert into cat_results values (1,'6 active umbrellas','6',v,v='6');

  select count(*)::text into v from public.main_category where level = 2 and is_active;
  insert into cat_results values (2,'34 active shelves','34',v,v='34');

  select count(*)::text into v from public.main_category where level = 3;
  insert into cat_results values (3,'no L3 nodes yet','0',v,v='0');

  select count(*)::text into v from public.main_category where level not between 1 and 3;
  insert into cat_results values (4,'no node outside levels 1-3','0',v,v='0');

  -- A child sits exactly one level below its parent. This single rule is also what
  -- makes cycles structurally impossible: closing a loop would need level to increase
  -- without bound around it.
  select count(*)::text into v
    from public.main_category c
    join public.main_category p on p.id = c.parent_id
   where c.level <> p.level + 1;
  insert into cat_results values (5,'level = parent.level + 1 everywhere','0',v,v='0');

  select count(*)::text into v
    from public.main_category where level > 1 and parent_id is null;
  insert into cat_results values (6,'no orphaned non-root','0',v,v='0');

  select count(*)::text into v
    from public.main_category where level = 1 and parent_id is not null;
  insert into cat_results values (7,'no root with a parent','0',v,v='0');

  select count(*)::text into v from public.main_category where parent_id = id;
  insert into cat_results values (8,'no self-parent','0',v,v='0');

  -- ==========================================================================
  -- Naming and identity
  -- ==========================================================================

  select count(*)::text into v from public.main_category where slug is null or slug = '';
  insert into cat_results values (9,'every category has a slug','0',v,v='0');

  select count(*)::text into v from (
    select slug from public.main_category group by slug having count(*) > 1
  ) d;
  insert into cat_results values (10,'slugs are unique','0',v,v='0');

  select count(*)::text into v from (
    select lower(name) from public.main_category group by lower(name) having count(*) > 1
  ) d;
  insert into cat_results values (11,'names are unique, case-insensitively','0',v,v='0');

  select count(*)::text into v
    from public.main_category where is_active and length(name) > 22;
  insert into cat_results values (12,'active names <= 22 chars','0',v,v='0');

  select count(*)::text into v
    from public.main_category
   where is_active and length(name) - length(replace(name,'&','')) > 1;
  insert into cat_results values (13,'active names have at most one &','0',v,v='0');

  select count(*)::text into v
    from public.main_category
   where is_active and (coalesce(name_hi,'') = '' or coalesce(name_hn,'') = '');
  insert into cat_results values (14,'active names carry hi + hn','0',v,v='0');

  -- Two siblings sharing a sort_order means an arbitrary display order, which is the
  -- bug the column exists to fix.
  select count(*)::text into v from (
    select parent_id, sort_order from public.main_category
     where is_active group by parent_id, sort_order having count(*) > 1
  ) d;
  insert into cat_results values (15,'no sibling shares a sort_order','0',v,v='0');

  -- ==========================================================================
  -- Products
  -- ==========================================================================

  select count(*)::text into v
    from public.products p
    join public.main_category c on c.id = p.main_category_id
   where c.level < 2;
  insert into cat_results values (16,'no product filed on an umbrella','0',v,v='0');

  select count(*)::text into v
    from public.products p
    join public.main_category c on c.id = p.main_category_id
   where p.is_active and c.slug = 'uncategorised';
  insert into cat_results values (17,'nothing active in the staging queue','0',v,v='0');

  select count(*)::text into v from public.products where is_active;
  insert into cat_results values (18,'35 active SKUs','35',v,v='35');

  select count(distinct main_category_id)::text into v
    from public.products where is_active;
  insert into cat_results values (19,'active SKUs across 10 shelves','10',v,v='10');

  -- A withdrawn product keeps every child row. Deleting it instead would take its
  -- variants, images and hand-built Hindi voice aliases with it.
  select count(*)::text into v
    from public.product_variants where product_id in (36,37);
  insert into cat_results values (20,'withdrawn SKUs keep their variants','> 0',v,v::int > 0);

  -- ==========================================================================
  -- Guards -- these attempt forbidden writes for real
  -- ==========================================================================

  select id into umbrella_id from public.main_category where level = 1 and is_active limit 1;
  select id into shelf_id from public.main_category where level = 2 and is_active limit 1;

  begin
    update public.products set main_category_id = umbrella_id
     where id = (select id from public.products order by id limit 1);
    insert into cat_results values (21,'filing a product on an umbrella is rejected','rejected','ALLOWED',false);
  exception when others then
    insert into cat_results values (21,'filing a product on an umbrella is rejected','rejected','rejected',true);
  end;

  begin
    insert into public.main_category (name, slug, parent_id, level)
    values ('ZZ Verify Orphan','zz-verify-orphan', null, 2);
    insert into cat_results values (22,'parentless level-2 is rejected','rejected','ALLOWED',false);
  exception when others then
    insert into cat_results values (22,'parentless level-2 is rejected','rejected','rejected',true);
  end;

  begin
    insert into public.main_category (name, slug, parent_id, level)
    values ('ZZ Verify Skip','zz-verify-skip', umbrella_id, 3);
    insert into cat_results values (23,'skipping a level is rejected','rejected','ALLOWED',false);
  exception when others then
    insert into cat_results values (23,'skipping a level is rejected','rejected','rejected',true);
  end;

  begin
    insert into public.main_category (name, slug, parent_id, level)
    values ('ZZ Verify Dup', (select slug from public.main_category where id = shelf_id),
            umbrella_id, 2);
    insert into cat_results values (24,'duplicate slug is rejected','rejected','ALLOWED',false);
  exception when others then
    insert into cat_results values (24,'duplicate slug is rejected','rejected','rejected',true);
  end;

  -- ==========================================================================
  -- The RPC the app actually calls
  -- ==========================================================================

  tree := public.category_tree();

  select jsonb_array_length(tree)::text into v;
  insert into cat_results values (25,'category_tree() returns 6 umbrellas','6',v,v='6');

  select count(*) into n
    from jsonb_array_elements(tree) r, jsonb_array_elements(r->'children') s
   where s->>'slug' in ('uncategorised','retired-electronics-appliances',
                        'retired-packaged-food');
  insert into cat_results values (26,'no retired or staging node in the payload','0',n::text,n=0);
end $$;

select n, check_name, expected, actual,
       case when pass then 'PASS' else '*** FAIL ***' end as result
from cat_results order by n;

ROLLBACK;
