-- Fixes the 3 rows flagged in the Phase 5 reconciliation report: `attribute` values that
-- are 100% scraped page noise (repeated product names, mangled UTF-8-as-Latin1 rupee
-- signs, "Add To Cart" button text -- one row (id 82) even leaked an unrelated Philips
-- LED bulb listing into a grocery product's info row). None of the three has any
-- salvageable original label text; `value` in every case is intact and legitimate, so the
-- row is recategorized rather than deleted.
--
-- Before:
--   product_info id 64:  attribute = "Slurrp Farm Fruit Cereal Trial Pack Slurrp Farm
--                         Fruit Cereal Trial Pack â‚¹ 223   â‚¹297 Add To Cart"
--   product_info id 82:  attribute = " â‚¹ 59   â‚¹155 Add To Cart Philips LED
--                         Compare Philips 9 W LED Bulb Cool White | 6500K | Energy "
--   product_highlights id 14: attribute = " Fortune Suji Fortune Suji Fortune Suji
--                         Fortune Suji Fortune Suji â‚¹ 29   â‚¹45 Add To Cart Fortune"
-- After: recategorized per the legitimate content already sitting in `value`.

update public.product_info set attribute = 'Manufacturer Details'
where id in (64, 82)
  and attribute like '%Add To Cart%';

update public.product_highlights set attribute = 'Description'
where id = 14
  and attribute like '%Add To Cart%';
