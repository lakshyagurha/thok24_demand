# Phase 1 — Schema conversion notes (MariaDB `thok24` → Postgres)

Source of truth: the **live local `thok24` database** (31 tables), not `Backend/digixcod_dxmart.sql`
(28 tables, missing `chat_messages` / `product_aliases` / `regular_orders`).

Migration: `supabase/migrations/20260724000001_initial_schema.sql` — 21 tables in `public`,
1 in `private`.

**Status: APPLIED** to project `asnjjkpjuqsmjqrjojzl` on 2026-07-24, after user review, together
with `20260724000002_rls_policies.sql`. Structure only — no data has been migrated yet (Phase 5).
Verified afterwards with `supabase/tests/rls_verification.sql`: 20/20 pass against the live schema.

---

## Table mapping

| MariaDB (31) | Postgres (22) | Note |
|---|---|---|
| `users` | `auth.users` + `public.user_profiles` | Identity moves to Supabase Auth (phone/OTP). Profile keeps `name`, `phone`, `status`, `legacy_user_id`. **No role column.** |
| `admin` | `private.admin_users` | Empty in source. Moved out of the exposed schema; staff auth via Edge Function + service role. |
| `otp_table` | *(dropped)* | Supabase Auth owns OTP issuance/expiry now. |
| `delivery_charge`, `delivey_charge`, `free_delivey`, `handling_charge`, `minimum_order_amout`, `deliver_time`, `help_call`, `help_email`, `help_whatsapp` | `app_settings` (key/value) | **All nine were empty.** Collapses the `delivey_`/`delivery_` typo pair and 7 more single-row config tables. Nothing to preserve. |
| `delivery_boy` | `delivery_boy` | `password` column **dropped** (riders don't log in; it was a plaintext surface). `date_time` varchar → `created_at timestamptz`. |
| everything else | same name | Types converted, FKs and indexes added. |

## Type conversions

- `int(11) AUTO_INCREMENT` → `bigint generated **by default** as identity` — *by default*, not *always*, so Phase 5 can insert legacy ids and preserve FK relationships.
- `decimal(10,2)` / `double(10,2)` → `numeric(10,2)`. `wholesale_price` was `double`, a MySQL-ism removed in MySQL 8; money must never be float.
- `latin1` tables (13 of them) → UTF-8. Verified lossless: those tables hold ASCII only today.
- Dates, all stored as varchar in the source:
  | Column | Source format | Becomes |
  |---|---|---|
  | `orders.order_datetime`, `users.date_time`, `delivery_boy.date_time` | `DD-MM-YYYY hh:mm AM` | `timestamptz` (parsed as Asia/Kolkata) |
  | `orders.delivery_date` | `YYYY-MM-DD` | `date` |
  | `orders.delivery_time` | `9 AM - 2 PM` | **stays text**, renamed `delivery_time_window` — it's a window, not a time |
  | `coupon.expri_date` | `DD-MM-YYYY` | `expiry_date date` (typo fixed) |

## Renames

- `orders.location_id` → `orders.delivery_address_id`. Verified against the data: values `{1,9,10,11,12}` are all `delivery_address.id`, and do **not** match `city.id` `{10,40,41}`. The old name was misleading.
- `coupon.expri_date` → `expiry_date`.

## Problems found in the source data (these would have broken Phase 5)

1. **3 orphaned `banner.category_id` values** (5, 6, 9) — those categories no longer exist. A `NOT NULL` FK would reject half the banner table. `category_id` is therefore **nullable** with `ON DELETE SET NULL`; Phase 5 nulls the orphans rather than deleting the banners.
2. **`order_items` has 1 orphaned `product_id` and 1 orphaned `variant_id`.** Both are nullable with `ON DELETE SET NULL` so order history survives catalog deletions instead of line items vanishing.
3. **`chat_messages.role` is `'bot'`, not `'assistant'`** — a CHECK constraint using the wrong vocabulary would have rejected 68 of 139 rows. Constraint matches the source and `process_chat.php`.

## Deliberate additions beyond a literal port — please confirm

1. **`order_items.unit_price numeric(10,2)` (nullable).** The source records **no price on the line item**, so once catalog prices change a past order's composition can't be reconstructed — only the order-level total survives. Nullable means existing rows migrate untouched (`NULL` = unknown historical price) while new orders can capture it. **Say the word and I'll drop it.**
2. **`app_settings`** replacing nine empty config tables (above).
3. **`CHECK (quantity > 0)`** on `cart_items` / `order_items` — verified: minimum in both is currently 1.
4. **Unique index on `lower(coupon.code_name)`** — verified: no duplicate codes today.
5. **Indexes on every foreign key.** The source had only 9 FK constraints total and no FK indexes.

## Left deliberately as-is

- **`products.types`** is a comma-separated tag list (`'normal,Everyday Essentials,Best selling'`). `text[]` + GIN would be the idiomatic Postgres shape, but it changes query semantics in the Flutter layer. Flagged as a follow-up, not done here.
- **`orders.status`** stays free text (observed: `pending`, `packed`, `way`, `delivered`). No CHECK constraint — the full state machine isn't documented and guessing it would break order writes.
- **`orders.gift`** stays text (observed values are inconsistent: `Rs0`, `noGift`).
- **`wholesale_price`** carried across structurally, referenced nowhere.

## Known blocker for Phase 5 (user migration)

Auth is moving to phone/OTP, but the source `users` table **has no phone column**. Phones are only
derivable via `delivery_address`, and:

- only **8 of 25 users** have one at all;
- some are invalid (11 digits: `83889958868`, `96434490655`);
- some are **shared across different users** (`8102337432` → users 1 and 20; `9630231236` → users 24 and 25).

`auth.users.phone` is unique, so these 25 test users **cannot be faithfully migrated to phone
identities**. Since all data is test/seed, the recommendation is to **not migrate users at all** —
start with an empty `auth.users` and re-register. Catalog, aliases, and settings migrate normally;
orders/cart/wishlist/chat belong to users that won't exist. To be decided at the Phase 5 checkpoint.

## RLS

Enabled on all 21 `public` tables (and on `private.admin_users` as defence in depth) with
**no policies** — which denies everything to `anon`/`authenticated` until Phase 2 adds policies
deliberately. That is the intended safe default, not an oversight.
