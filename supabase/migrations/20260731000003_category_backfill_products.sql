-- Phase 3 of the category taxonomy work. See docs/category-system-plan.md §3.5.
--
-- GENERATED FROM supabase/tools/category_backfill.py -- do not hand-edit. Change the
-- mapping there and re-run `python3 supabase/tools/category_backfill.py --emit-sql`.
--
-- Moves every product onto the new tree and withdraws two SKUs. Nothing is deleted:
-- withdrawal is `is_active = false`, which keeps each product's variants, images, info,
-- highlights and hand-built Hindi voice aliases intact.
--
-- Run the dry run first -- it prints this whole remap against live data and refuses to
-- proceed if any product would land on an umbrella, a non-leaf or a missing shelf:
--
--     python3 supabase/tools/category_backfill.py

begin;

-- ---------------------------------------------------------------------------
-- 1. Remap
-- ---------------------------------------------------------------------------

update public.products p
   set main_category_id = c.id
  from (values
  (  1, 'atta-rice-dal'),         -- Bhagyalakshmi Rice Flour
  (  2, 'atta-rice-dal'),         -- Fortune Chakki Fresh Atta
  (  3, 'atta-rice-dal'),         -- Tata Sampann Unpolished Green Moong
  (  4, 'dry-fruits-seeds'),      -- Sri Bhagyalakshmi Ground Nut
  (  5, 'atta-rice-dal'),         -- Fortune Suji
  (  6, 'oil-ghee-masala'),       -- Akshayakalpa Organic Desi Cow Ghee
  (  7, 'atta-rice-dal'),         -- Aashirvaad Superior MP Atta
  (  8, 'oil-ghee-masala'),       -- Fortune Kachi Ghani Mustard Oil
  (  9, 'atta-rice-dal'),         -- Fortune Sona Masoori Supreme Raw Aged Rice
  ( 10, 'atta-rice-dal'),         -- Fortune Unpolished Kabuli Chana
  ( 11, 'sauces-spreads'),        -- 9am Tomato Ketchup
  ( 12, 'sauces-spreads'),        -- Kissan Fresh Tomato Ketchup
  ( 13, 'breakfast-cereal'),      -- Kellogg's Chocos
  ( 14, 'sauces-spreads'),        -- MyFitness Original Peanut Butter
  ( 15, 'sauces-spreads'),        -- Hellmann's Eggless Mayonnaise
  ( 16, 'sauces-spreads'),        -- Akshayakalpa Wild Honey
  ( 17, 'dry-fruits-seeds'),      -- Popular Fit Eats Chia Seeds
  ( 18, 'breakfast-cereal'),      -- Slurrp Farm Fruit Cereal Trial Pack
  ( 19, 'tea-coffee-drinks'),     -- Taj Mahal Deccan Rose Tea
  ( 20, 'sauces-spreads'),        -- Dabur Honey Squeezy
  ( 21, 'breakfast-cereal'),      -- Kellogg's Muesli Fruit Nut & Seeds
  ( 22, 'dry-fruits-seeds'),      -- Khari Foods Kalmi Dates / Khajur
  ( 23, 'dairy-bread-eggs'),      -- Amul Taaza Homogenised Toned Milk
  ( 24, 'bulbs-batteries'),       -- Philips 9 W LED Bulb Cool White
  ( 25, 'dairy-bread-eggs'),      -- Nestle EveryDay Dairy Whitener
  ( 26, 'dairy-bread-eggs'),      -- Britannia 100% Whole Wheat Bread
  ( 27, 'dairy-bread-eggs'),      -- Amul Salted Butter
  ( 28, 'dairy-bread-eggs'),      -- Amul Fresh Malai Paneer
  ( 29, 'dairy-bread-eggs'),      -- Amul Masti Dahi Cup
  ( 30, 'biscuits-bakery'),       -- Cake Tale Muffin Vanilla Chocochip
  ( 31, 'biscuits-bakery'),       -- Theobroma Christmas Plum Cake
  ( 32, 'dairy-bread-eggs'),      -- Vijay White Eggs
  ( 33, 'dairy-bread-eggs'),      -- Amul Fresh Cream
  ( 34, 'kitchen-appliances'),    -- Havells Insta Cook QT 1200 W Induction Cooktop
  ( 35, 'kitchen-appliances')     -- Bajaj GX-1 Mixer Grinder 500W
) as v(product_id, slug)
  join public.main_category c on c.slug = v.slug
 where p.id = v.product_id
   and p.main_category_id is distinct from c.id;

-- ---------------------------------------------------------------------------
-- 2. Withdraw the two consumer gadgets
-- ---------------------------------------------------------------------------
--
--   36: Noise ColorFit Icon 2 Vista Smartwatch
--   37: Mivi Roam2 Bluetooth Speaker
--
-- DxMart is a grocery and daily-essentials shop. These stay in the database, keep every
-- child row, and come back with a single `is_active = true` if that changes.

update public.products
   set is_active = false
 where id in (36, 37);

-- ---------------------------------------------------------------------------
-- 3. Assertions
-- ---------------------------------------------------------------------------

do $$
declare
  n_on_umbrella int; n_unfiled int; n_active int; n_shelves int;
begin
  select count(*) into n_on_umbrella
    from public.products p
    join public.main_category c on c.id = p.main_category_id
   where c.level < 2;
  if n_on_umbrella > 0 then
    raise exception '% products are filed on an umbrella, not a shelf', n_on_umbrella;
  end if;

  select count(*) into n_unfiled
    from public.products p
    join public.main_category c on c.id = p.main_category_id
   where c.slug = 'uncategorised' and p.is_active;
  select count(*) into n_active from public.products where is_active;
  if n_active > 0 and n_unfiled::numeric / n_active > 0.02 then
    raise exception
      'Uncategorised holds % of % active SKUs, over the 2%% ceiling -- the tree is wrong',
      n_unfiled, n_active;
  end if;

  select count(distinct main_category_id) into n_shelves
    from public.products where is_active;
  raise notice
    'category backfill: % active SKUs across % shelves, % unfiled', n_active, n_shelves, n_unfiled;
end;
$$;

commit;
