-- Phase 2 of the category taxonomy work. See docs/category-system-plan.md §3.
--
-- Builds the tree: 6 umbrellas (L1) over 34 shelves (L2). Of those 34 shelves, 10 are
-- the existing rows renamed and reparented -- ids are REUSED wherever the meaning
-- survives, so their images and the banners pointing at them keep working -- and 24 are
-- new. Two existing rows are retired (kept, deactivated, never deleted).
--
-- Naming rules enforced on every row here, and re-checked by
-- supabase/tools/category_backfill.py --dry-run:
--   * Title Case, at most one "&", no "& More" / "& Dals" filler
--   * <= 22 characters (longest is "Beauty & Personal Care", exactly 22)
--   * name_hi (Devanagari) and name_hn (romanized Hinglish) present on every row
--   * unique slug, unique lower(name)
--
-- Devanagari is written as literal UTF-8 rather than the U&'\0906...' escapes the Phase 5
-- data migration used. That form came out of the MariaDB export tool; written by hand it
-- is unreviewable, and this file has to be read by a human before it is applied.
--
-- No row is deleted and no product is touched. Products are remapped in ...03.

begin;

-- ---------------------------------------------------------------------------
-- 0. Snapshot, so the rollback has something to restore from
-- ---------------------------------------------------------------------------

create table if not exists private.category_migration_backup (
  taken_at         timestamptz not null default now(),
  main_category    jsonb       not null,
  products         jsonb       not null
);
revoke all on private.category_migration_backup from anon, authenticated;

insert into private.category_migration_backup (main_category, products)
select
  (select jsonb_agg(to_jsonb(m) order by m.id) from public.main_category m),
  (select jsonb_agg(jsonb_build_object(
            'id', p.id, 'main_category_id', p.main_category_id, 'is_active', p.is_active)
          order by p.id)
     from public.products p);

-- ---------------------------------------------------------------------------
-- 1. The six umbrellas
-- ---------------------------------------------------------------------------
--
-- These are the only nodes with icon_url set to a path that does not exist yet. The six
-- icon assets are a manual step (plan checklist 2.3) -- until they are uploaded the app
-- falls back to Icons.category_outlined, which ProductImage already handles, so this is
-- safe to apply before the artwork exists.

insert into public.main_category
  (name, name_hi, name_hn, slug, parent_id, level, sort_order, is_active, icon_url)
values
  ('Grocery & Kitchen',      'किराना और रसोई',    'Kirana Aur Rasoi',
   'grocery-kitchen',      null, 1, 1, true, 'category/icon_grocery_kitchen.png'),
  ('Snacks & Drinks',        'नाश्ता और पेय',       'Nashta Aur Peya',
   'snacks-drinks',        null, 1, 2, true, 'category/icon_snacks_drinks.png'),
  ('Household Essentials',   'घर की ज़रूरतें',      'Ghar Ki Zaruratein',
   'household-essentials', null, 1, 3, true, 'category/icon_household_essentials.png'),
  ('Beauty & Personal Care', 'निजी देखभाल',        'Niji Dekhbhal',
   'beauty-personal-care', null, 1, 4, true, 'category/icon_beauty_personal_care.png'),
  ('Baby & Wellness',        'शिशु और सेहत',       'Shishu Aur Sehat',
   'baby-wellness',        null, 1, 5, true, 'category/icon_baby_wellness.png'),
  ('Home & Electricals',     'घर और बिजली सामान',  'Ghar Aur Bijli Saman',
   'home-electricals',     null, 1, 6, true, 'category/icon_home_electricals.png'),

  -- Not a category. This is the parent of the admin-only staging shelf below: a product
  -- must sit at level >= 2, so the queue needs a root to hang from. Both are inactive
  -- and never reach the app. Sorted last so it cannot be mistaken for a real umbrella.
  ('Unfiled',                'अवर्गीकृत',           'Avargikrit',
   'unfiled',              null, 1, 99, false, null);

-- ---------------------------------------------------------------------------
-- 2. Reparent, rename and order the ten existing shelves that survive
-- ---------------------------------------------------------------------------
--
-- `image` holds the existing category artwork (a real product photo, per the CategoryBar
-- comment). It is copied into `icon_url` so there is one field the app reads; `image` is
-- left populated and is treated as deprecated rather than dropped.

update public.main_category m set
  parent_id = p.id,
  level     = 2,
  name      = v.name,
  name_hi   = v.name_hi,
  name_hn   = v.name_hn,
  slug      = v.slug,
  sort_order= v.sort_order,
  is_active = true,
  icon_url  = coalesce(m.icon_url, m.image)
from (values
  -- id, parent slug,        new name,               name_hi,                new name_hn,            slug,                  sort
  --                                                          was: "Fruits & Vegetables" (unchanged)
  (27, 'grocery-kitchen',   'Fruits & Vegetables',   'फल और सब्ज़ियाँ',      'Fal Aur Sabziyan',      'fruits-vegetables',   1),
  --                                                          was: "Atta, Rice, Oil & Dals" -- oil split out
  (23, 'grocery-kitchen',   'Atta, Rice & Dal',      'आटा, चावल और दाल',    'Atta, Chawal Aur Dal',  'atta-rice-dal',       2),
  --                                                          was: "Dairy, Bread & Eggs" (unchanged)
  (25, 'grocery-kitchen',   'Dairy, Bread & Eggs',   'डेयरी, ब्रेड और अंडे',  'Dairy, Bread Aur Ande', 'dairy-bread-eggs',    5),
  --                                                          was: "Masala & Dry Fruits" -- masala split out
  (30, 'grocery-kitchen',   'Dry Fruits & Seeds',    'सूखे मेवे और बीज',     'Sukhe Meve Aur Beej',   'dry-fruits-seeds',    6),
  --                                                          was: "Breakfast & Sauces" -- sauces split out
  (24, 'snacks-drinks',     'Breakfast & Cereal',    'नाश्ता और अनाज',      'Nashta Aur Anaj',       'breakfast-cereal',    1),
  --                                                          was: "Sweet Cravings" -- a mood, not a shelf
  (32, 'snacks-drinks',     'Sweets & Chocolates',   'मिठाई और चॉकलेट',     'Mithai Aur Chocolate',  'sweets-chocolates',   4),
  --                                                          was: "Tea, Coffee & More"
  (33, 'snacks-drinks',     'Tea, Coffee & Drinks',  'चाय, कॉफ़ी और पेय',    'Chai, Coffee Aur Peya', 'tea-coffee-drinks',   5),
  --                                                          was: "Ice Creams & More"
  (28, 'snacks-drinks',     'Ice Cream & Desserts',  'आइसक्रीम और मिठाई',   'Ice Cream Aur Dessert', 'ice-cream-desserts',  7),
  --                                                          was: "Frozen Food"
  (31, 'snacks-drinks',     'Instant & Frozen Food', 'इंस्टेंट और फ्रोज़न',    'Instant Aur Frozen',    'instant-frozen-food', 8),
  --                                                          was: "Kitchen & Dining" (unchanged, moved umbrella)
  (29, 'home-electricals',  'Kitchen & Dining',      'रसोई और भोजन',        'Rasoi Aur Bhojan',      'kitchen-dining',      1)
) as v(id, parent_slug, name, name_hi, name_hn, slug, sort_order)
join public.main_category p on p.slug = v.parent_slug
where m.id = v.id;

-- ---------------------------------------------------------------------------
-- 3. Retire the two that cannot be saved
-- ---------------------------------------------------------------------------
--
-- 26 "Electronics & Appliances": the home screen already hides it with a hardcoded name
--    filter in Dart. Its bulb and appliances move to real shelves in ...03; the
--    smartwatch and speaker are withdrawn.
-- 34 "Packaged Food": undefinable against its siblings -- every packaged SKU in the
--    catalog is packaged food -- so it can never be filled correctly. Its range is
--    covered by Chips & Namkeen, Biscuits & Bakery and Instant & Frozen Food.
--
-- Both keep their names so the retirement stays auditable, and both keep every row that
-- references them. `is_active = false` is the whole retirement.

update public.main_category m set
  parent_id = p.id,
  level     = 2,
  slug      = v.slug,
  sort_order= 98,
  is_active = false,
  icon_url  = coalesce(m.icon_url, m.image)
from (values
  (26, 'home-electricals', 'retired-electronics-appliances'),
  (34, 'snacks-drinks',    'retired-packaged-food')
) as v(id, parent_slug, slug)
join public.main_category p on p.slug = v.parent_slug
where m.id = v.id;

-- ---------------------------------------------------------------------------
-- 4. The twenty-four new shelves
-- ---------------------------------------------------------------------------
--
-- icon_url is null on all of these: there is no artwork for them yet. The app falls back
-- to Icons.category_outlined. Per the decision on 2026-07-31 they render with a
-- "Coming soon" treatment until stocked, rather than being hidden.

insert into public.main_category
  (name, name_hi, name_hn, slug, parent_id, level, sort_order, is_active)
select v.name, v.name_hi, v.name_hn, v.slug, p.id, 2, v.sort_order, v.is_active
from (values
  -- Grocery & Kitchen -------------------------------------------------------
  ('Oil, Ghee & Masala',    'तेल, घी और मसाला',      'Tel, Ghee Aur Masala',
   'oil-ghee-masala',    'grocery-kitchen',      3, true),
  ('Salt, Sugar & Jaggery', 'नमक, चीनी और गुड़',      'Namak, Cheeni Aur Gud',
   'salt-sugar-jaggery', 'grocery-kitchen',      4, true),
  ('Sauces & Spreads',      'सॉस और स्प्रेड',        'Sauce Aur Spread',
   'sauces-spreads',     'grocery-kitchen',      7, true),

  -- Snacks & Drinks ---------------------------------------------------------
  ('Chips & Namkeen',       'चिप्स और नमकीन',        'Chips Aur Namkeen',
   'chips-namkeen',      'snacks-drinks',        2, true),
  ('Biscuits & Bakery',     'बिस्किट और बेकरी',      'Biscuit Aur Bakery',
   'biscuits-bakery',    'snacks-drinks',        3, true),
  ('Cold Drinks & Juices',  'कोल्ड ड्रिंक और जूस',    'Cold Drink Aur Juice',
   'cold-drinks-juices', 'snacks-drinks',        6, true),

  -- Household Essentials ----------------------------------------------------
  ('Cleaning & Detergent',  'सफ़ाई और डिटर्जेंट',     'Safai Aur Detergent',
   'cleaning-detergent', 'household-essentials', 1, true),
  ('Pooja Needs',           'पूजा सामग्री',          'Pooja Samagri',
   'pooja-needs',        'household-essentials', 2, true),
  ('Disposables & Foil',    'डिस्पोज़ेबल और फ़ॉइल',    'Disposable Aur Foil',
   'disposables-foil',   'household-essentials', 3, true),
  ('Pest & Freshener',      'कीटनाशक और फ्रेशनर',    'Kitnashak Aur Freshener',
   'pest-freshener',     'household-essentials', 4, true),
  ('Paper & Stationery',    'कागज़ और स्टेशनरी',      'Kagaz Aur Stationery',
   'paper-stationery',   'household-essentials', 5, true),

  -- Beauty & Personal Care --------------------------------------------------
  ('Bath & Body',           'नहाना और शरीर',         'Nahana Aur Sharir',
   'bath-body',          'beauty-personal-care', 1, true),
  ('Hair Care',             'बालों की देखभाल',        'Balon Ki Dekhbhal',
   'hair-care',          'beauty-personal-care', 2, true),
  ('Oral Care',             'दाँतों की देखभाल',       'Danton Ki Dekhbhal',
   'oral-care',          'beauty-personal-care', 3, true),
  ('Skin & Face Care',      'त्वचा और चेहरा',        'Twacha Aur Chehra',
   'skin-face-care',     'beauty-personal-care', 4, true),
  ('Shaving & Grooming',    'शेविंग और ग्रूमिंग',      'Shaving Aur Grooming',
   'shaving-grooming',   'beauty-personal-care', 5, true),
  ('Feminine Hygiene',      'महिला स्वच्छता',        'Mahila Swachhta',
   'feminine-hygiene',   'beauty-personal-care', 6, true),

  -- Baby & Wellness ---------------------------------------------------------
  ('Baby Food & Care',      'शिशु आहार और देखभाल',   'Shishu Aahar Dekhbhal',
   'baby-food-care',     'baby-wellness',        1, true),
  ('Health & Nutrition',    'सेहत और पोषण',          'Sehat Aur Poshan',
   'health-nutrition',   'baby-wellness',        2, true),
  ('First Aid & Medicine',  'फ़र्स्ट एड और दवा',      'First Aid Aur Dawa',
   'first-aid-medicine', 'baby-wellness',        3, true),
  -- Flagged in the plan: the one shelf with least evidence of demand in
  -- Sagar/Khurai/Bina. Seeded active; flip is_active to false from the admin if you
  -- would rather not advertise it.
  ('Pet Care',              'पालतू देखभाल',          'Paltu Dekhbhal',
   'pet-care',           'baby-wellness',        4, true),

  -- Home & Electricals ------------------------------------------------------
  ('Bulbs & Batteries',     'बल्ब और बैटरी',         'Bulb Aur Battery',
   'bulbs-batteries',    'home-electricals',     2, true),
  ('Kitchen Appliances',    'रसोई उपकरण',            'Rasoi Upkaran',
   'kitchen-appliances', 'home-electricals',     3, true),
  ('Home Improvement',      'घर की मरम्मत',          'Ghar Ki Marammat',
   'home-improvement',   'home-electricals',     4, true),

  -- Admin-only staging ------------------------------------------------------
  -- Not an "Others" bucket: it is inactive, so it never renders in the app. It exists
  -- so an operator who cannot place a product has somewhere visible to park it, and so
  -- that pile is a work queue rather than a customer-facing shelf. The dry-run tool
  -- fails the build if it ever holds more than 2% of active SKUs.
  ('Uncategorised',         'अवर्गीकृत सामान',        'Avargikrit Saman',
   'uncategorised',      'unfiled',              1, false)
) as v(name, name_hi, name_hn, slug, parent_slug, sort_order, is_active)
join public.main_category p on p.slug = v.parent_slug;

-- ---------------------------------------------------------------------------
-- 5. Prove the pre-existing rows conform, then hand the sequence back
-- ---------------------------------------------------------------------------

-- Deferred from ...01, where the 12 legacy rows were still parentless. Every row now
-- has a parent or is level 1, so this can be validated for real.
alter table public.main_category validate constraint main_category_root_ck;

-- The L1s and the 24 new shelves took ids from the identity sequence. Phase 5 set it to
-- max(id) after inserting with explicit ids, so this is belt-and-braces for a replay
-- against a database that has drifted.
select setval(
  pg_get_serial_sequence('public.main_category', 'id'),
  greatest((select coalesce(max(id), 0) from public.main_category), 1)
);

-- ---------------------------------------------------------------------------
-- 6. Assertions -- this migration fails rather than half-applying
-- ---------------------------------------------------------------------------

do $$
declare
  n_l1 int; n_l2 int; n_bad_name int; n_no_slug int; n_dup_sort int;
begin
  select count(*) into n_l1 from public.main_category where level = 1 and is_active;
  if n_l1 <> 6 then
    raise exception 'expected 6 active umbrellas, found %', n_l1;
  end if;

  select count(*) into n_l2 from public.main_category where level = 2 and is_active;
  if n_l2 <> 34 then
    raise exception 'expected 34 active shelves, found %', n_l2;
  end if;

  -- Naming rules, enforced rather than documented.
  select count(*) into n_bad_name
    from public.main_category
   where is_active
     and (length(name) > 22
          or length(name) - length(replace(name, '&', '')) > 1
          or coalesce(name_hi, '') = ''
          or coalesce(name_hn, '') = '');
  if n_bad_name > 0 then
    raise exception
      '% active categories break the naming rules (>22 chars, >1 "&", or missing hi/hn)',
      n_bad_name;
  end if;

  select count(*) into n_no_slug
    from public.main_category where slug is null or slug = '';
  if n_no_slug > 0 then
    raise exception '% categories have no slug', n_no_slug;
  end if;

  -- Two siblings sharing a sort_order means an arbitrary display order, which is the
  -- bug this column exists to fix.
  select count(*) into n_dup_sort from (
    select parent_id, sort_order
      from public.main_category
     where is_active
     group by parent_id, sort_order
    having count(*) > 1
  ) d;
  if n_dup_sort > 0 then
    raise exception '% sibling groups share a sort_order', n_dup_sort;
  end if;
end;
$$;

commit;
