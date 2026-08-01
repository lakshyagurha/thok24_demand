-- Rollback for 20260731000004_category_tree_rpc.sql.
--
-- Apply FIRST of the four rollbacks: the function and view depend on columns that
-- ...01_down removes.
--
-- Safe to run on its own. Dropping these only removes the one-call read path; the
-- tree data itself is untouched, and the app can still read main_category directly.

drop function if exists public.category_tree();
drop view if exists public.v_category_health;
