# DxMart → Supabase Migration & Production Hardening — Project Brief

This file is the persistent context for Claude Code on this project. It was produced after a full
read-through of the existing codebase in a separate planning session (Cowork). Read this file in
full before touching any code, running any command, or connecting to any database.

## 0. What this project is

DxMart is a grocery/kirana ordering app, and it sits inside a larger startup, THOK24. THOK24's
mission is to modernize Bharat's kirana (small neighborhood grocery) stores by supplying them
directly from manufacturers (cutting out wholesaler layers) and by taking daily operating
headaches off their plate — Hindi-first, voice + WhatsApp, no heavy app the shopkeeper has to
learn. THOK24 is pre-revenue, currently validating cheaply in Sagar/Khurai/Bina (Madhya Pradesh)
before spending on anything unproven.

DxMart is the consumer-facing (B2C) side of this: households order groceries via voice or normal
browsing, fulfilled from the nearest partner kirana store. The same underlying app/schema is
intended to later serve kirana store owners themselves for B2B inventory ordering (aggregated
demand, wholesale pricing) — these two audiences should share one backend and ideally one
codebase with role-based behavior, not be forked into two separate apps, unless volume later
proves that's necessary.

**Operating principles to hold this project to (from the THOK24 charter — apply them here too):**
- Prove cheaply, gate every spend. Don't build ahead of proof.
- Asset-light first.
- The kirana/user is never a disposable node — don't design anything that silently degrades
  their experience for our convenience.
- Hindi-first, hyperlocal, voice + WhatsApp — no heavy new app patterns the target user has to
  learn.
- Trust real data over assumptions in this document. If what you find in the code or from me
  contradicts something written here, say so — this brief will keep evolving.

## 1. Current state of the codebase (as of the last full read-through)

**Stack:** Backend is raw PHP (procedural, mysqli, no framework) against MariaDB, currently
hosted locally via XAMPP. Frontend is two separate Flutter apps: `Frontend/dx_mart` (consumer
app) and `Frontend/dxmart_admin` (internal admin/ops app).

> **Corrected 2026-07-24.** This section was written before a full re-audit. Fixes inline below,
> marked ✅ where the original claim was verified and ❌ where it was wrong.

❌ *"There is no git repository yet"* — **git exists** and has since before the migration started.
`.gitignore` is sound (`build/`, `.env`, `*.key`, `error_log`, `uploads/` all excluded and
untracked). Migration work lives on the `supabase-migration` branch.

❌ *"hosted locally via XAMPP"* is incomplete — there is also a **live public deployment** at
`dxmart.digixcode.com` and `digimart.digixcode.com`. Both are demo/test only, with no real
customer data (confirmed by Lakshya, 2026-07-24). The local dev database is named **`thok24`**,
not `dxmart`; `Backend/digixcod_dxmart.sql` is a *production-side* export from Jan 2026 and is
**incomplete** (28 tables vs the live 31 — it lacks `chat_messages`, `product_aliases` and
`regular_orders`). Treat the live `thok24` database as the schema source of truth, not the dump.

**Feature surface (already built, don't discard):** category/product/variant catalog with
images, cart, wishlist, coupons, delivery charge/time-window rules, multiple delivery addresses,
order placement with an admin dashboard, sales reports, PDF invoice generation, a `delivery_boy`
table for rider assignment, and a multilingual schema (`name_hi`/`name_hn` columns) already
migrated in. Notably, `product_variants` already has a `wholesale_price` column alongside
`selling_price` — the schema was already designed with the future B2B/kirana reuse in mind.

**Voice ordering ("BolKeOrder") — already prototyped, this is a real asset:** on-device
speech-to-text (`speech_to_text` package), a "Ramu Bhai" chat avatar persona, a bill/"parchi" UI,
and a backend bot (`Backend/api_folder/bot/process_chat.php`) that does regex-based
quantity/unit extraction with a Gemini 2.5 Flash fallback for messier Hindi/Hinglish input,
matched against a `product_aliases` table (e.g. moong → dal/daal/mung) with repeat-order recall
via a `regular_orders` table. This cheap-deterministic-first, LLM-fallback-second architecture is
the right shape — harden it, don't replace it.

**Confirmed problems (found by direct code read, not guesswork):**
- ❌ SQL injection — **understated in the original brief.** It is **30 non-vendor files**, not 19,
  and it is *not* concentrated in `auth/`. All **10** of the `auth/` files are injectable (not 8
  of 9), plus 20 more outside it: `location/*`, `main_category/{delete,edit}`, seven files under
  `product/`, `wishlist/get_wishlist`, `delivery_address/*`, `banner_api/delete_banner` and
  `place_order/order_assignment`. 34 files do use `->prepare()`. This is an app-wide problem, not
  an auth-folder one.
- `Backend/api_folder/admin_login.php` compares the admin password in **plaintext**, not hashed.
- No real auth/session/token layer anywhere. Every endpoint trusts a `user_id` sent by the client
  in the request body/query string with no verification — meaning any client can currently read
  or modify any other user's cart, orders, wishlist, or addresses by changing an ID. This is the
  single biggest risk in the app, bigger than the choice of database.
- `Backend/api_folder/bot/process_chat.php` has a live Gemini API key hardcoded directly in the
  source, called over curl with `CURLOPT_SSL_VERIFYPEER` disabled. **This key must be rotated —
  treat it as already compromised** since it's sat in a plain-text file.
- ✅ CORS is wide open on every endpoint — though the mechanism is one line in
  `Backend/api_folder/connection.php`, which every endpoint includes. One file, not 96.
- ❗ **Not in the original brief:** a second live secret, a **Gmail App Password**, was hardcoded
  at `place_order/send_email_background.php:46`. `auth/login.php` also returned the full user row
  — including the bcrypt password hash — to the client. `place_order.php` computed the cart
  subtotal server-side but took `discount_amount`, `delivery_charge` and **`final_amount` from the
  request body**, so a client could submit an order at any price it chose.
- No environment separation: `Frontend/dx_mart/lib/.../api_constants.dart` hardcodes a local LAN
  IP (`192.168.31.10`) as the API base URL — this only works on the office WiFi today.
- No rate limiting, no centralized input validation, inconsistent per-folder `error_log` files
  instead of structured logging.

## 2. Decisions already made (don't re-litigate these without new evidence)

- **Replatform the backend onto Supabase; do not attempt a literal "point the connection string
  at a new host" migration.** Supabase is Postgres, not MySQL/MariaDB — every query needs
  translating regardless (auto-increment → identity columns, `ON DUPLICATE KEY UPDATE` →
  `ON CONFLICT`, backtick identifiers, etc.), and mysqli can't talk to Postgres at all. Since a
  real rewrite of the data-access layer is unavoidable, use it to fix the auth/session gap
  properly: Supabase Auth for real sessions, Row Level Security to structurally replace "every
  endpoint manually checks user_id" with a database-enforced rule, Supabase Storage to replace
  the local `/uploads` folder, and Edge Functions (TypeScript/Deno) for anything needing a secret
  (the Gemini call, Razorpay webhook verification, email sending).

  ❌ **The original rationale for phone/OTP was wrong.** It claimed "there's already an
  `otp_table`, so this maps naturally". `otp_table` is `(id, email, otp, expiry)` — **email**-based
  — and the `users` table has **no phone column at all**. Phone/OTP is a *new* feature needing an
  SMS provider with real per-message cost, not a natural mapping. Lakshya chose it anyway
  (2026-07-24), which is clean here only because all existing data is test/seed, so there are no
  real bcrypt passwords or accounts to preserve.
- **Keep both Flutter apps and the BolKeOrder feature.** Rewrite their data layer for the
  `supabase_flutter` SDK plus calls to the new Edge Functions, but the UI/UX and the
  voice-ordering logic shape stay.

  ❌ *"swap `http` calls in `api_constants.dart`-style service classes"* assumed a service layer
  that **does not exist**. Only `dx_mart/lib/BolKeOrder/services` was ever a service; **39 of 68
  Dart files call `package:http` inline from inside widgets** (28 consumer, 11 admin). The layer
  had to be *built*, not swapped — it now lives in `dx_mart/lib/core/` and `dx_mart/lib/data/`.
- ❌ **B2C/B2B reuse — REVERSED on 2026-07-24. DxMart is consumer-only.**
  There are no kirana/retailer accounts, no B2B ordering and no role-based pricing. **Do not add
  a `role` or `account_type` field.** Do not build any RLS policy, view or UI logic that
  distinguishes user types or exposes `wholesale_price`; that column stays in the schema
  untouched and unreferenced. If B2B is ever wanted, it will be planned as a separate effort —
  do not design for it now.

  *(The superseded instruction read: add a role/account-type field and gate `selling_price` vs.
  `wholesale_price` by role. Ignore it.)*
- **Local-first workflow:** use the Supabase CLI (`supabase init` / `supabase start`, which runs a
  full local Postgres+Auth+Storage stack via Docker) to develop and test exactly as XAMPP is used
  today, and only push to a hosted Supabase project once things work locally.
- **Cost/timing:** Supabase's free tier is sufficient for the Sagar/Khurai/Bina pilot (500MB DB,
  1GB storage, 50k MAU, 500k edge function calls). Move to the Pro plan ($25/mo) once a real pilot
  user depends on this, since free projects auto-pause after a week of inactivity and have no
  automatic backups.

## 3. How I want you (Claude Code) to work on this

1. **Audit before acting.** Re-verify the findings in section 1 yourself against the live repo —
   this brief may be slightly stale by the time you read it. Don't trust it blindly, and tell me
   where it's wrong.
2. **Git first, always.** If there's still no git repository when you start, initialize one and
   make a clean baseline commit before making any other change. Every subsequent change should be
   a reviewable commit/diff, not a silent edit.
3. **Plan before executing.** Produce a written, phased plan (schema conversion → RLS policies →
   Edge Functions → Flutter rewrite → data migration dry run → cutover, roughly) and show it to me
   before writing code against it. Don't chain all phases into one uninterrupted run.
4. **Ask me, don't assume, when it's a business-rule question.** Things like: what exactly
   distinguishes a "kirana retailer" account from a "household" account, what minimum order
   quantities or credit terms apply, what the actual cutover timeline is, whether a Supabase
   project already exists or needs creating, whether Razorpay/Gemini/other API keys need
   rotating right now or already have replacements ready. If something in this brief is
   ambiguous or missing for a decision you're about to make, stop and ask me instead of guessing.
5. **RLS policies get read by me line by line before they're applied anywhere with real data.**
   Never disable RLS or fall back to the service-role key from client code to unblock yourself if
   a policy is denying access — that recreates the exact "any client can access any user's data"
   bug this migration exists to fix. Flag the policy problem to me instead of routing around it.
6. **No destructive or irreversible action without explicit go-ahead** — this includes anything
   that drops/alters production data, force-pushes, or runs a data migration against anything
   other than a disposable/test project, until I've confirmed it's safe.
7. **Use sub-agents where the work is genuinely parallel and low-risk** (e.g., converting
   independent groups of PHP endpoints to Edge Functions, writing Flutter service classes for
   unrelated modules, drafting RLS policies per table for later review) — but you (the primary
   agent) own the plan, the checkpoints, and reporting back to me. Don't let sub-agents apply
   migrations or touch a real database directly without a checkpoint back to me first.
8. **Connect the Supabase MCP** if it isn't already connected, and use it for anything that's
   safe to do read/write against a project we've confirmed is a dev/staging project. Confirm
   which Supabase project (new vs. existing) before connecting anything to it.

## 3a. Migration status (updated 2026-07-24)

Branch `supabase-migration`. Supabase project ref **`asnjjkpjuqsmjqrjojzl`** — confirmed a dev
project; it was completely empty before this work.

- **Phase 0 — done.** Both hardcoded secrets removed from source, TLS verification restored,
  `connection.php` fixed (it pointed at a non-existent `dxmart` database) and made env-driven.
  ⚠️ **Rotation of the Gemini key and Gmail App Password at the providers is still outstanding
  and is Lakshya's action.** They remain in git history regardless.
- **Phase 1 — done and APPLIED.** 21 tables in `public` + 1 in `private`, 24 FKs, 50 indexes.
- **Phase 2 — done and APPLIED.** 30 RLS policies, pure ownership, no role logic.
  Regression test: `supabase/tests/rls_verification.sql` (self-cleaning, rolls back).
- **Phase 3 — done and DEPLOYED.** Five Edge Functions, all ACTIVE:
  `place-order`, `process-chat`, `admin-api`, `send-order-email`, `razorpay-webhook`.
  Secrets still to set: `GEMINI_API_KEY`, `RESEND_API_KEY` + `ORDER_EMAIL_FROM`,
  `RAZORPAY_WEBHOOK_SECRET`, `ALLOWED_ORIGINS`. Each degrades safely without them.
- **Phase 4 — done.** Corrected 2026-07-25: this line previously read "in progress ...
  Admin app not started," which was stale by the time of the pre-Phase-6 audit. Both apps
  are fully migrated off the PHP backend — zero `package:http` calls remain in either
  `lib/` tree (verified by grep, not just by reading commit messages). Consumer app:
  auth, catalog browse, cart, wishlist, search, product details, checkout, orders,
  profile, addresses, help, location and voice ordering all migrated. Admin app: settings,
  main category, product, coupon, banner, location, user, dashboard, order and stock
  screens all migrated, all writes routed through the `admin-api` Edge Function (verified:
  zero direct `.from(...).insert/update/delete` calls in `dxmart_admin/lib`).
- **Phase 5 — done.** Catalog data (district, city, main_category, products,
  product_variants, product_images, product_info, product_highlights, product_aliases,
  banner, coupon, delivery_boy — 744 rows, 12 tables) migrated from the live `thok24`
  MariaDB database. Row counts, FK integrity and Devanagari fidelity all verified exact.
  User-owned data intentionally excluded — see §4.
- **Pre-Phase-6 audit — done (2026-07-25).** RLS proved against the real live schema and
  policies (not just the miniature replica in `rls_verification.sql`) via
  `supabase/tests/rls_live_verification.sql`, all 21 checks passing. Every deployed Edge
  Function's source reviewed. Fixed: a redundant storage listing policy, a false-failure
  edge case in `place-order` after order commit, a non-constant-time auth check in
  `send-order-email`, dead legacy `api_constants.dart` files in both apps, and 3
  mojibake/scraped-noise data rows from Phase 5.
- **Phase 6 (cutover) — not started.**

**Key architectural rule now in force:** no client may write `orders`, and no repository method
accepts a user id. Identity comes from the verified JWT; RLS enforces ownership in the database.
If something appears to need a client-supplied `user_id`, that is a bug, not a requirement.

Verification tooling:
- `supabase/tests/rls_verification.sql` — 20 RLS checks against the live schema.
- `Frontend/dx_mart/tool/verify_rls.dart` — 15 checks as a real anonymous client.
  Run with `dart run tool/verify_rls.dart` (NOT `flutter test`: the test binding stubs all HTTP
  to status 400, so network assertions there are meaningless).
- `deno test supabase/functions/_shared/intent_test.ts` — 16 voice-extraction tests.

## 4. Open questions — ANSWERED 2026-07-24

- ~~Do I already have a Supabase project?~~ **Yes**, ref `asnjjkpjuqsmjqrjojzl`, connected via
  MCP (`.mcp.json`). It was empty; migrations 1 and 2 are now applied to it.
- ~~Role model for kirana vs. households?~~ **Not applicable — consumer-only.** See §2.
- ~~Pilot date?~~ **None fixed.** Optimize for correctness and low risk over speed.
- ~~Secrets rotated?~~ **No — still outstanding, and it is step zero.** Both the Gemini key and
  the Gmail App Password were live in source. Removed from the working tree, but they are in git
  history and must be rotated at the providers.
- ~~Real vs. test data?~~ **All test/seed**, both locally and on the digixcode.com demo
  deployment. The Phase 5 dry run can therefore be aggressive and repeatable. ⚠️ Re-confirm this
  before any destructive step if real pilot users have onboarded since.

### Still open / decide before the relevant phase
- **SMS provider for phone OTP** (MSG91, Twilio, …) — not chosen, and phone login does not work
  until one is configured in Supabase Auth. Real per-message cost; gate it like any other spend.
- **User migration is blocked and probably unnecessary.** Only 8 of 25 test users have a
  derivable phone (via `delivery_address`), some are invalid 11-digit numbers, and some are
  *shared between different users*. `auth.users.phone` is unique, so they cannot be migrated
  faithfully. Recommendation: migrate catalog + the 295 `product_aliases` only, and let test
  accounts re-register. Decide at the Phase 5 checkpoint.
- **`send-order-email` uses Resend, not Gmail.** Edge Functions cannot open raw SMTP sockets.
  Keeping Gmail would require an SMTP relay in front. Needs a call.
- **`order_items.unit_price`** was added (nullable) so order history survives price changes; the
  source recorded no line price at all. Say if you would rather port exactly and drop it.
- **`products.types`** is still a comma-separated tag string. `text[]` + GIN is the idiomatic
  Postgres shape; deferred because it changes query semantics in the Flutter layer.
