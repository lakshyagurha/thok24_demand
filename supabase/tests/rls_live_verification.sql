-- RLS verification against the REAL live schema, not a replica.
--
-- rls_verification.sql (this directory) seeds its own miniature copy of the tables and
-- policies so it can run against an empty project -- but that means it only proves the
-- copy is correct, not that the actually-deployed policies still match. If a policy is
-- edited in a migration and this file isn't updated to match, rls_verification.sql keeps
-- passing while testing something that no longer exists in production.
--
-- This file instead runs against public.cart_items, public.orders, etc. directly, using
-- two throwaway auth.users rows. It requires the real schema (all migrations through
-- 20260724000005_phase5_catalog_data_migration.sql) to already be applied, so it belongs
-- in CI/pre-deploy checks rather than a fresh empty project.
--
-- Safe to run against any environment with real data: everything happens inside a
-- transaction that ends in ROLLBACK, so no rows, users or tables survive it. Verified
-- (2026-07-25) with a real duplicate-key collision against the handle_new_user trigger
-- (which auto-creates a public.user_profiles row on auth.users insert) followed by a
-- clean post-rollback recheck -- confirms ROLLBACK genuinely discards everything here,
-- including the auth.users rows.
--
-- Run with:  supabase db query --file supabase/tests/rls_live_verification.sql
--        or: paste into the SQL editor / MCP execute_sql
--
-- Expect 21 rows, all PASS. Any '*** FAIL ***' is a security regression -- do not deploy.

BEGIN;

create temp table live_results(n int, check_name text, expected text, actual text, pass boolean);
grant all on live_results to authenticated, anon;

do $$
declare
  pid bigint; vid bigint;
  uA uuid := 'aaaaaaaa-0000-4000-8000-000000000001';
  uB uuid := 'bbbbbbbb-0000-4000-8000-000000000002';
  orderA bigint; orderB bigint;
  v text;
begin
  select id into pid from public.products order by id limit 1;
  select id into vid from public.product_variants where product_id = pid order by id limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  values (uA,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','livetest-a@t.local',now(),now()),
         (uB,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','livetest-b@t.local',now(),now());

  -- handle_new_user() already inserted a user_profiles row for each; update, don't insert.
  update public.user_profiles set name='A' where id=uA;
  update public.user_profiles set name='B' where id=uB;
  insert into public.cart_items (user_id, product_id, variant_id, quantity) values (uA, pid, vid, 2), (uB, pid, vid, 5);
  insert into public.wishlist (user_id, product_id) values (uA, pid), (uB, pid);
  insert into public.chat_messages (user_id, role, message) values (uA,'user','hi A'), (uB,'user','hi B');
  insert into public.delivery_address (user_id, name, phone, full_address, pin_code)
    values (uA,'A','9000000001','addr A','470001'), (uB,'B','9000000002','addr B','470001');
  insert into public.regular_orders (user_id, product_id, variant_id) values (uA, pid, vid), (uB, pid, vid);

  insert into public.orders (user_id, total_amount, final_amount) values (uA, 100, 100) returning id into orderA;
  insert into public.orders (user_id, total_amount, final_amount) values (uB, 200, 200) returning id into orderB;
  insert into public.order_items (order_id, product_id, variant_id, quantity) values (orderA, pid, vid, 2);
  insert into public.order_items (order_id, product_id, variant_id, quantity) values (orderB, pid, vid, 5);

  -- === act as User A ===
  perform set_config('role','authenticated',true);
  perform set_config('request.jwt.claims', json_build_object('sub',uA,'role','authenticated')::text, true);

  select count(*)::text into v from public.cart_items where user_id in (uA,uB);
  insert into live_results values (1,'cart_items: A sees only own row','1',v,v='1');

  select count(*)::text into v from public.wishlist where user_id in (uA,uB);
  insert into live_results values (2,'wishlist: A sees only own row','1',v,v='1');

  select count(*)::text into v from public.chat_messages where user_id in (uA,uB);
  insert into live_results values (3,'chat_messages: A sees only own row','1',v,v='1');

  select count(*)::text into v from public.delivery_address where user_id in (uA,uB);
  insert into live_results values (4,'delivery_address: A sees only own row','1',v,v='1');

  select count(*)::text into v from public.regular_orders where user_id in (uA,uB);
  insert into live_results values (5,'regular_orders: A sees only own row','1',v,v='1');

  select count(*)::text into v from public.orders where user_id in (uA,uB);
  insert into live_results values (6,'orders: A sees only own order','1',v,v='1');

  select count(*)::text into v from public.order_items where order_id in (orderA,orderB);
  insert into live_results values (7,'order_items: A sees only own order''s items (inherited)','1',v,v='1');

  select count(*)::text into v from public.user_profiles where id in (uA,uB);
  insert into live_results values (8,'user_profiles: A sees only own profile','1',v,v='1');

  select count(*)::text into v from public.products;
  insert into live_results values (9,'catalog: A can read products','> 0',v,v::int > 0);

  select count(*)::text into v from public.coupon;
  insert into live_results values (10,'coupon: A sees only Public rows','2',v,v='2');

  begin
    select count(*)::text into v from public.delivery_boy;
    insert into live_results values (11,'delivery_boy PII unreachable','denied','READABLE '||v,false);
  exception when insufficient_privilege then
    insert into live_results values (11,'delivery_boy PII unreachable','denied','denied',true);
  end;

  begin
    select count(*)::text into v from private.admin_users;
    insert into live_results values (12,'private.admin_users unreachable','denied','READABLE '||v,false);
  exception when others then
    insert into live_results values (12,'private.admin_users unreachable','denied','denied ('||sqlstate||')',true);
  end;

  update public.cart_items set quantity=99 where user_id=uB;
  get diagnostics v = row_count;
  insert into live_results values (13,'A cannot update B''s cart row','0 rows',v||' rows',v='0');

  begin
    update public.cart_items set user_id=uB where user_id=uA;
    get diagnostics v = row_count;
    insert into live_results values (14,'A cannot hand own cart row to B (WITH CHECK)','blocked',v||' rows updated',false);
  exception when others then
    insert into live_results values (14,'A cannot hand own cart row to B (WITH CHECK)','blocked','blocked '||sqlstate,true);
  end;

  begin
    insert into public.orders (user_id, total_amount, final_amount) values (uA, 1, 0.01);
    insert into live_results values (15,'A cannot INSERT into orders directly (no policy)','blocked','INSERT SUCCEEDED',false);
  exception when others then
    insert into live_results values (15,'A cannot INSERT into orders directly (no policy)','blocked','blocked '||sqlstate,true);
  end;

  begin
    update public.orders set status='delivered' where user_id=uA;
    get diagnostics v = row_count;
    insert into live_results values (16,'A cannot UPDATE own order (no policy; only place-order/webhook via service role)','0 rows',v||' rows',v='0');
  exception when others then
    insert into live_results values (16,'A cannot UPDATE own order (no policy)','0 rows','blocked '||sqlstate,true);
  end;

  begin
    insert into public.order_items (order_id, product_id, variant_id, quantity) values (orderA, pid, vid, 1);
    insert into live_results values (17,'A cannot INSERT into order_items directly (no policy)','blocked','INSERT SUCCEEDED',false);
  exception when others then
    insert into live_results values (17,'A cannot INSERT into order_items directly (no policy)','blocked','blocked '||sqlstate,true);
  end;

  update public.user_profiles set name='hacked' where id=uB;
  get diagnostics v = row_count;
  insert into live_results values (18,'A cannot update B''s profile','0 rows',v||' rows',v='0');

  -- === act as an anonymous visitor ===
  perform set_config('role','anon',true);
  perform set_config('request.jwt.claims','{"role":"anon"}',true);

  select count(*)::text into v from public.products;
  insert into live_results values (19,'anon: can browse catalog','> 0',v,v::int > 0);

  begin
    select count(*)::text into v from public.cart_items;
    insert into live_results values (20,'anon: no cart access','0 or denied',v,v='0');
  exception when insufficient_privilege then
    insert into live_results values (20,'anon: no cart access','0 or denied','denied',true);
  end;

  begin
    select count(*)::text into v from public.orders;
    insert into live_results values (21,'anon: no order access','0 or denied',v,v='0');
  exception when insufficient_privilege then
    insert into live_results values (21,'anon: no order access','0 or denied','denied',true);
  end;
end $$;

RESET ROLE;
select n, check_name, expected, actual,
       case when pass then 'PASS' else '*** FAIL ***' end as result
from live_results order by n;

ROLLBACK;
