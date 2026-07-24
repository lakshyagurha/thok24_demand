# DxMart Phase 6 — Cutover Runbook

Written 2026-07-25, after end-to-end verification against the live dev project
`asnjjkpjuqsmjqrjojzl`. Read the whole thing before starting; step 1 protects against the
only irreversible mistake available here.

---

## Where things actually stand

**The backend is functionally proven.** A 33-check end-to-end suite ran against the real
project over real HTTP with two real signed-in users — not role simulation. All 33 passed.
It is reproducible: `supabase/tools/cutover_e2e.py` (see "Re-running the proof" below).

The headline result: `place-order` was sent a deliberately hostile request body claiming
`total_amount: 0.01`, `final_amount: 0.01`, `discount_amount: 9999`. The server ignored
every one of those fields and computed ₹60 subtotal → ₹75 final from the catalog. **The
"client can name its own price" vulnerability that this migration exists to fix is closed
and demonstrably so.** Likewise, user A asking PostgREST explicitly for user B's rows
(`?user_id=eq.<B>`) — the exact attack the old PHP allowed — returns nothing.

**But cutover cannot happen yet.** Three hard blockers below, in priority order.

---

## STEP 1 — Do this before touching anything (irreversible risk)

**101 catalog images exist in the database as paths, but the storage bucket is empty.**
The image bytes live only under `Backend/api_folder/`. Of them, the **154 files in
`uploads/` are gitignored and untracked** (`.gitignore:62`) — they exist only on this
machine and on the live digixcode.com server. `banner/` (6) and `category/` (16) are
tracked and recoverable from git; the product photos are not.

**Deleting or moving `Backend/` before copying these would destroy every product photo in
the catalog, permanently, with no backup anywhere.**

A dry run confirms all 101 referenced images are present on disk right now, with zero
broken references. Copy them first:

```bash
# 1. Inventory (read-only, no secret needed, safe anytime)
python3 supabase/tools/migrate_storage.py

# 2. Perform the copy
SUPABASE_SERVICE_ROLE_KEY='<service_role key from dashboard>' \
  python3 supabase/tools/migrate_storage.py --apply
```

Get the key from **Supabase dashboard → Project Settings → API → `service_role`**. It is a
full-access credential: never commit it and never put it in a Flutter build. The bucket
deliberately has no client INSERT policy, which is why this needs the service role.

Verify afterwards: the script reports `uploaded: 101, failed: 0`, and a product image
renders in the app. Only then is `Backend/` safe to retire.

---

## Hard blockers

### A. No SMS provider — consumer login does not work at all *(decision + spend)*

`Frontend/dx_mart/lib/data/auth_repository.dart:35` calls `signInWithOtp(phone:)` and
verifies with `OtpType.sms`. The project's enabled auth providers are, verified via
`/auth/v1/settings`, **email only** — phone is off and no SMS provider is wired up.
(`sms_provider: twilio` in that response is an unset default, not a configured provider.)

**Consequence: not one consumer user can sign in.** The app code is correct; the
configuration does not exist.

This is a spend decision, so it is yours to make, not mine to assume. It needs: an SMS
provider account (MSG91 is usually cheaper for Indian traffic than Twilio and supports the
DLT registration Indian carriers require), the sender/DLT template registration, and then
Supabase Auth → Providers → Phone configured with the credentials. Per-message cost is
real and recurring — gate it like any other spend, and note that OTP SMS to Indian numbers
requires DLT template approval which takes days, so start early if you want it.

*Interim option if you want to pilot before paying for SMS:* the admin app already uses
email/password successfully, and the consumer app could be pointed at the same mechanism
for a closed test group. That is a code change to `auth_repository.dart` plus the OTP
screen, not a config toggle — say the word if you want it and I'll scope it.

### B. `private.admin_users` is empty — the admin app is unusable by anyone

`admin-api` returns 403 to any caller not in that table (verified in the e2e run). It has
**0 rows**, so every admin action fails for everybody.

Unlike blocker A this is free to fix, but it needs a real auth user to point at. The admin
app signs in with **email/password** (`dxmart_admin/lib/Auth/login_screen.dart:81`), which
already works today. Create the staff account through the dashboard
(**Authentication → Users → Add user**, with "Auto Confirm" on), then:

```sql
insert into private.admin_users (id) values ('<that useruuid>');
```

Tell me the email you want and I'll do this end to end.

### C. Razorpay webhook cannot verify payments

`RAZORPAY_WEBHOOK_SECRET` is unset, so the function **fails closed** — it returns 500 and
refuses to act (correct, verified in the e2e run: an unsigned payload was rejected). But
that means **online payments can never be confirmed**. Set the secret before enabling any
non-COD payment method, or restrict payment to COD at launch.

---

## Configuration still required

Set under **Supabase dashboard → Edge Functions → Secrets**. Every function degrades
safely without its secret, so nothing crashes — features are simply inert.

| Secret | Unset today means | Severity |
|---|---|---|
| `RAZORPAY_WEBHOOK_SECRET` | payments never confirm (blocker C) | blocks paid orders |
| `ALLOWED_ORIGINS` | no CORS header is emitted at all; fine for native Flutter, breaks any web build | needed only for web |
| `GEMINI_API_KEY` | voice ordering silently loses its LLM fallback — deterministic Hindi/Hinglish parsing still works, messier phrasing does not | degrades BolKeOrder |
| `RESEND_API_KEY` + `ORDER_EMAIL_FROM` | no order confirmation emails are sent (order still places correctly) | user-visible gap |
| `ORDER_EMAIL_BCC` | optional internal copy of each order | optional |

**Email auth caveat:** if email login is used for anything beyond the admin account,
note that `mailer_autoconfirm` is false and the project is on Supabase's default SMTP,
which is rate-limited to a few messages per hour — I hit `over_email_send_rate_limit` on
the *second* signup while testing. Production email auth needs custom SMTP configured.

---

## Security actions still outstanding

1. **Rotate the Gemini API key and the Gmail App Password at their providers.** Open since
   Phase 0. Both were committed in plaintext and remain in git history regardless of the
   working tree being clean. Until rotated, treat both as compromised.
2. **`Backend/api_folder/phpinfo.php`** — full PHP configuration disclosure. If it is
   reachable on digixcode.com it is an active information-disclosure hole *today*, before
   any cutover. Worth deleting from the live server now rather than waiting.
3. **`Backend/digixcod_dxmart.sql` is tracked in git** and contains a plaintext admin
   password plus 25 users' bcrypt hashes, emails and phone numbers. All test data, but it
   is real PII shape sitting in history. Decide: keep as archive, or purge from history.
4. **Legacy CORS**: three `.htaccess` files under `Backend/` set
   `Access-Control-Allow-Origin: *`. They die with the folder — no action if the folder
   goes.

---

## Accepted functional regressions — confirm before go-live

These are things the PHP backend did that Supabase does not. None is a bug; each is a
deliberate or discovered gap. Confirm you accept them.

1. **Auto-translate is gone.** `translate_api.php` proxied Google Translate to autofill
   Hindi/Hinglish names. Admin screens now show *"Auto-translate is unavailable. Please
   enter the Hindi and Hinglish names."* Staff must hand-type `name_hi`/`name_hn` for every
   new product, category, info attribute and highlight. For a Hindi-first product this is
   ongoing manual load — worth a decision, not just an acknowledgement.
2. **No bulk alias generation.** `bot/generate_aliases.php` built `product_aliases` from
   product names. The 295 existing aliases migrated fine, but **new products get none**, so
   voice ordering silently degrades for them (it falls back to matching
   `products.name/name_hi/name_hn`). There is no admin UI for aliases; they can only be
   added one row at a time. If BolKeOrder matters, this needs a plan.
3. **Rider assignment does not exist.** `order_assignment.php` / `fetch_delivery_orders.php`
   referenced an `order_assignment` table that exists in neither the dump nor the live
   database, and `orders` has no `delivery_boy_id`. It never worked. Treat rider assignment
   as a net-new feature, not a migration.
4. **`delivery_boy` has no UI.** The table migrated (2 rows) and is reachable via
   `admin-api`, but no admin screen manages it and there was never a rider login.
5. **Private coupons preview as ₹0 discount.** RLS hides `status='Private'` coupons from
   clients, so the checkout preview shows no discount until `place-order` validates the
   code server-side and applies it. Intentional; flagging so it isn't filed as a bug.

---

## Cutover sequence

Do not start until blockers A–C are resolved and the regressions above are accepted.

1. **Copy imagery to Storage** (STEP 1 above). Verify `failed: 0`. **Do not skip.**
2. **Seed the admin account** (blocker B) and confirm login to the admin app works.
3. **Set Edge Function secrets** (table above).
4. **Configure phone auth** (blocker A) and confirm a real OTP round-trip on a real
   handset.
5. **Move off the free tier before real users arrive.** Free projects auto-pause after 7
   days of inactivity and have **no automatic backups** — an unacceptable combination once
   a pilot user's order history matters. Pro is $25/mo. Confirm Point-in-Time Recovery or
   at minimum daily backups is on before go-live.
6. **Re-run the proof** (below) against the final configuration. Expect 33/33.
7. **Build both Flutter apps against the project** and smoke-test on a real device:
   browse → add to cart → checkout → order history; admin login → change an order status.
   ```bash
   flutter build apk --dart-define=SUPABASE_URL=https://asnjjkpjuqsmjqrjojzl.supabase.co \
                     --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
   ```
8. **Only now retire the PHP backend.** Take digixcode.com offline first and watch for a
   few days before deleting anything — DNS/hosting for
   `dxmart.digixcode.com` / `digimart.digixcode.com` is configured **outside this repo**
   and must be torn down manually. Keep `Backend/` on disk until the imagery copy has been
   verified in production.

## Rollback

Until step 8, rollback is simply "keep using the PHP backend" — nothing about the Supabase
work is destructive to it. The two apps are the only things that switch over, and they
switch via `--dart-define`, so shipping a previous build reverts the client side.

The genuinely one-way doors, in order of danger:
- deleting `Backend/api_folder/product_api_project/uploads/` (154 untracked product photos)
- tearing down digixcode.com hosting
- purging git history for the SQL dump

Everything else is reversible.

## Re-running the proof

```bash
python3 supabase/tools/cutover_e2e.py
```

Creates two throwaway users, exercises catalog/cart/wishlist/address/order/admin paths
including hostile-input cases, prints a PASS/FAIL table, then deletes both users — every
dependent row cascades, verified. Expect `33/33 passed`. Any FAIL is a release blocker.

Complementary SQL-level check (proves the policies themselves, inside Postgres):
`supabase/tests/rls_live_verification.sql` — 21 checks, all passing, self-rolling-back.
