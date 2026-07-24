-- Seeds app_settings with the pricing rules the PHP backend hardcoded.
--
-- The nine single-row config tables this replaced were all EMPTY in the source, so there
-- is nothing to migrate. These values are recovered from the constants in
-- bot/process_chat.php, which is where the running system actually got them:
--   handling = 5.0
--   delivery = subtotal < 500 ? 10.0 : 0.0
--
-- Deliberately NOT seeded: help_call, help_email and help_whatsapp. Those are real
-- business contact details and inventing them would put a wrong number in front of a
-- customer. The client reads app_settings defensively and omits the contact when a key
-- is absent, so leaving them out is safe. Set them from the admin app.

insert into public.app_settings (key, value) values
  ('handling_charge',         '5'),
  ('delivery_charge',         '10'),
  ('free_delivery_threshold', '500'),
  ('minimum_order_amount',    '0')
on conflict (key) do nothing;
