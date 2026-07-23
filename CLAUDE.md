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
app) and `Frontend/dxmart_admin` (internal admin/ops app). There is **no git repository** in this
project yet — this needs to be fixed before any large-scale automated changes are made, so every
change is diffable and revertible.

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
- SQL injection: 19 of 96 PHP files build queries via raw string interpolation instead of
  prepared statements — concentrated almost entirely in `Backend/api_folder/auth/` (8 of 9 files:
  login, signup, forgot/reset password, OTP verify, edit profile, user status). The other 34
  files correctly use `->prepare()`, so the pattern is known but wasn't applied consistently on
  the most sensitive surface.
- `Backend/api_folder/admin_login.php` compares the admin password in **plaintext**, not hashed.
- No real auth/session/token layer anywhere. Every endpoint trusts a `user_id` sent by the client
  in the request body/query string with no verification — meaning any client can currently read
  or modify any other user's cart, orders, wishlist, or addresses by changing an ID. This is the
  single biggest risk in the app, bigger than the choice of database.
- `Backend/api_folder/bot/process_chat.php` has a live Gemini API key hardcoded directly in the
  source, called over curl with `CURLOPT_SSL_VERIFYPEER` disabled. **This key must be rotated —
  treat it as already compromised** since it's sat in a plain-text file.
- CORS is wide open (`Access-Control-Allow-Origin: *`) on every endpoint, including admin login.
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
  properly: Supabase Auth (with phone/OTP — there's already an `otp_table`, so this maps
  naturally) for real sessions, Row Level Security to structurally replace "every endpoint
  manually checks user_id" with a database-enforced rule, Supabase Storage to replace the local
  `/uploads` folder, and Edge Functions (TypeScript/Deno) for anything needing a secret (the
  Gemini call, Razorpay webhook verification, email sending).
- **Keep both Flutter apps and the BolKeOrder feature.** Rewrite their data layer (swap `http`
  calls in `api_constants.dart`-style service classes for the `supabase_flutter` SDK plus calls to
  the new Edge Functions), but the UI/UX and the voice-ordering logic shape stay.
- **B2C/B2B reuse:** don't fork into two Flutter apps yet. Add a role/account-type field to the
  user model (household vs. kirana retailer), and use RLS policies to gate `selling_price` vs.
  the already-existing `wholesale_price`, catalog visibility, and minimum-order rules by role.
  Revisit forking only once B2B volume actually justifies maintaining two codebases.
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

## 4. Open questions to raise with me before or during Phase 1

- Do I already have a Supabase account/project, or does one need creating?
- What's the actual role model for kirana retailers vs. households — pricing tiers, minimum
  order quantities, credit terms, anything beyond wholesale_price vs. selling_price?
- Timeline: is there a specific pilot date in Sagar/Khurai/Bina this needs to be ready for?
- Have the exposed secrets (Gemini API key, admin credentials) been rotated yet, or should that
  be step zero?
- Any data in the current XAMPP database that's real/live vs. test/seed data — i.e., how careful
  do we need to be with the data migration step specifically?
