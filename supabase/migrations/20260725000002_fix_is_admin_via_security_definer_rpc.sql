-- Fixes a latent bug that made the entire admin app non-functional.
--
-- admin-api's isAdmin() read private.admin_users through PostgREST with the service-role
-- key:
--     serviceClient().schema("private").from("admin_users")...
--
-- That never worked. PostgREST only serves schemas on its exposed list -- for this
-- project `public, graphql_public` -- so the call always failed with
-- `PGRST106: Invalid schema: private` (confirmed directly against the REST endpoint),
-- isAdmin() always returned false, and admin-api returned 403 to every caller
-- unconditionally.
--
-- It went unnoticed through Phase 3 because private.admin_users was empty: a genuine
-- "you are not staff" and a broken membership check are indistinguishable from outside.
-- It only surfaced in Phase 6 when the first real admin was seeded and still got 403.
--
-- The obvious fix -- adding `private` to PostgREST's exposed schemas -- would defeat the
-- reason that schema exists. Instead expose one narrow SECURITY DEFINER function that
-- answers exactly the yes/no question and nothing more. It cannot be used to enumerate
-- staff: it takes an id and returns a boolean.
--
-- EXECUTE is granted to service_role only, so anon/authenticated cannot call it and a
-- client cannot probe whether a given user id is an admin. `search_path = ''` plus a
-- fully-qualified table reference is the standard SECURITY DEFINER hardening, so a
-- caller-controlled search_path cannot redirect `private.admin_users` at another table.
--
-- Verified after deploying admin-api v3: the seeded admin gets 200 on list/order_status,
-- a non-staff signed-in user still gets 403, an unauthenticated caller still gets 401,
-- and the table allowlist still rejects `admin_users` itself.

create or replace function public.is_admin(check_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (select 1 from private.admin_users a where a.id = check_id);
$$;

revoke all on function public.is_admin(uuid) from public;
revoke all on function public.is_admin(uuid) from anon;
revoke all on function public.is_admin(uuid) from authenticated;
grant execute on function public.is_admin(uuid) to service_role;
