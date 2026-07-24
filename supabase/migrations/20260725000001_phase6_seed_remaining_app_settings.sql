-- Phase 5 migrated the catalog but missed four config values that lived in their own
-- single-row legacy tables (help_call, help_email, help_whatsapp, deliver_time). The
-- consumer app reads all four: help_screen.dart renders the three contact channels, and
-- delivery_time is shown on homeScreen, product_card, product_details and track_order.
-- Without these rows those screens fall back to blank/"Not available" -- a real
-- degradation for a Hindi-first user whose support path is a phone call or WhatsApp.
--
-- Values are copied verbatim from the live thok24 MariaDB, not invented:
--   help_call      1 row -> 6205511711
--   help_whatsapp  1 row -> 6205511711
--   help_email     1 row -> support@digixcode.com
--   deliver_time   1 row -> '10 minutes'
--
-- Change support@digixcode.com if support should route somewhere other than the agency
-- address once THOK24 runs its own inbox.
--
-- With this applied, app_settings holds all 8 keys its table comment documents.

insert into public.app_settings (key, value) values
  ('help_call',     '6205511711'),
  ('help_whatsapp', '6205511711'),
  ('help_email',    'support@digixcode.com'),
  ('delivery_time', '10 minutes')
on conflict (key) do nothing;
