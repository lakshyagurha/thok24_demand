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

**Status after the 2026-07-25 working session: one blocker left.**

| Blocker | State |
|---|---|
| Imagery not in Storage (irreversible risk) | ✅ resolved — 101/101 copied and verified |
| Admin app unusable | ✅ resolved — account seeded, plus a latent `is_admin` bug fixed |
| Razorpay cannot confirm payments | ✅ deferred by decision — COD-only launch, guarded in code |
| **No SMS provider → no consumer can log in** | ❌ **open — MSG91 chosen, DLT registration is the long pole** |

Cutover is gated on that last row and nothing else.

---

## STEP 1 — Imagery copy ✅ DONE 2026-07-25

**Completed. 101/101 objects uploaded, 0 failed.** Independently verified: zero broken
references remain across `product_images`, `banner` and `main_category`; three sample
public URLs return real image bytes (PNG/JPEG/WebP); anonymous bucket listing still
returns nothing, so images are fetchable but not enumerable.

`Backend/` is now safe to retire *from an imagery standpoint*. Keep it until the apps are
confirmed working in production anyway — see step 8. The original warning is preserved
below because it still governs any future change to those folders.

<details>
<summary>Original risk description (kept for context)</summary>

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

</details>

---

## Hard blockers

### A. No SMS provider — consumer login does not work at all *(decision + spend)*

`Frontend/dx_mart/lib/data/auth_repository.dart:35` calls `signInWithOtp(phone:)` and
verifies with `OtpType.sms`. The project's enabled auth providers are, verified via
`/auth/v1/settings`, **email only** — phone is off and no SMS provider is wired up.
(`sms_provider: twilio` in that response is an unset default, not a configured provider.)

**Consequence: not one consumer user can sign in.** The app code is correct; the
configuration does not exist.

**Decision made 2026-07-25: MSG91.** Steps, in the order they gate each other:

1. **Create the MSG91 account** and get an Auth Key.
2. **Register DLT** (Distributed Ledger Technology) — mandatory for A2P SMS to Indian
   numbers. Register the Principal Entity, then a Sender ID (6 alpha chars, e.g. `THOK24`),
   then the OTP **content template**. The template text must match what is actually sent,
   variable placeholders included. **Approval takes days, sometimes 1–2 weeks.** Nothing
   else here is blocked by it, so start this first and let it run in the background.
3. Once approved, configure **Supabase dashboard → Authentication → Providers → Phone**:
   enable phone, select MSG91, paste the Auth Key and Sender ID / template ID.
4. **Turn off "Enable phone confirmations" bypasses** and leave `phone_autoconfirm` off —
   the OTP *is* the verification; auto-confirm would defeat it.
5. Verify on a real handset: the app's `sendOtp` → `verifyOtp` round-trip must produce a
   session. `normalisePhone()` already converts `9876543210` → `+919876543210`, so test
   with a plain 10-digit entry the way a real user types it.

No app code changes are needed — `auth_repository.dart` is already correct and provider-
agnostic. This is purely configuration plus the DLT wait.

*Cost note:* per-message cost is real and recurring. Every OTP send is billable, including
retries and mistyped numbers, so watch the "resend" behaviour in `Auth/otpScreen.dart`
during the pilot.

### B. Admin access ✅ RESOLVED 2026-07-25 — *and it uncovered a real bug*

`thok24ops@gmail.com` now exists as a confirmed auth user and is registered in
`private.admin_users`. Verified working: list orders, read catalog, read user profiles.

**Seeding the row was not sufficient, and this is the important part.** With the admin
seeded, `admin-api` *still* returned 403. Root cause: `isAdmin()` read
`private.admin_users` through PostgREST, which only serves schemas on its exposed list
(`public, graphql_public`). The call failed with `PGRST106: Invalid schema: private` on
every request, so `isAdmin()` returned false for **everyone, always** — the admin app has
been non-functional since Phase 3. An empty `admin_users` table hid it perfectly, because
"you are not staff" and "the check is broken" look identical from outside.

Fixed without exposing the private schema: `public.is_admin(uuid)` is a SECURITY DEFINER
function, `EXECUTE` granted to `service_role` only, that answers the membership question
and nothing else (migration `20260725000002`, `admin-api` v3). Re-verified: seeded admin
gets 200, **non-staff signed-in user still gets 403**, unauthenticated still 401, and the
table allowlist still rejects `admin_users` itself.

To add more staff later:
```sql
-- create the auth user first (dashboard -> Authentication -> Users -> Add user,
-- with "Auto Confirm" on), then:
insert into private.admin_users (id, email) values ('<user uuid>', '<their email>');
```

### C. Razorpay cannot confirm payments — *resolved for launch: COD only*

`RAZORPAY_WEBHOOK_SECRET` is unset, so `razorpay-webhook` **fails closed** — it returns 500
and refuses to act (correct, and verified: an unsigned payload was rejected). But that
means an online payment could never be confirmed, leaving the order stuck at `pending`
while the customer believes they have paid.

**Decision made 2026-07-25: launch COD-only.** Rather than rely on the client never
offering the option, `place-order` now refuses `RAZORPAY` outright whenever the webhook
secret is absent, returning *"Online payment is unavailable right now. Please choose Cash
on Delivery."* (place-order v3; verified live — `RAZORPAY` is rejected, `COD` proceeds
normally).

The guard is self-clearing: **setting `RAZORPAY_WEBHOOK_SECRET` re-enables online payment
with no code change and no redeploy.** When you do enable it, verify a real signed webhook
actually flips an order's status before taking live money.

---

## Configuration still required

Set under **Supabase dashboard → Edge Functions → Secrets**. Every function degrades
safely without its secret, so nothing crashes — features are simply inert.

| Secret | Unset today means | Severity |
|---|---|---|
| `RAZORPAY_WEBHOOK_SECRET` | online payment is refused with a clear message; COD unaffected | deferred by choice |
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

0. **Start MSG91 DLT registration now** (blocker A, step 2). It is the long pole — days to
   weeks of external approval — and nothing else waits on it. Kick it off, then continue.
   **← this is the only remaining blocker**
1. ~~Copy imagery to Storage~~ ✅ done — 101/101, verified.
2. ~~Seed the admin account~~ ✅ done — plus the `is_admin` bug it exposed, now fixed.
3. **Set Edge Function secrets** (table above). `RAZORPAY_WEBHOOK_SECRET` is deliberately
   skipped for a COD-only launch. `GEMINI_API_KEY` and `RESEND_API_KEY` +
   `ORDER_EMAIL_FROM` are worth setting — see the severity column.
4. **Finish phone auth** once DLT clears, and confirm a real OTP round-trip on a real
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
