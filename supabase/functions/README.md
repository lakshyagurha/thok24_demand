# Edge Functions

Five functions replacing the PHP endpoints that needed a secret or server-side authority.

| Function | Replaces | Auth | Needs secrets |
|---|---|---|---|
| `place-order` | `place_order.php` | User JWT | none (uses auto-injected `SUPABASE_*`) |
| `admin-api` | `admin_login.php` + admin CRUD | User JWT + staff check | none |
| `process-chat` | `bot/process_chat.php` | User JWT | `GEMINI_API_KEY` (optional) |
| `send-order-email` | `send_email_background.php` | service-role only | `RESEND_API_KEY`, `ORDER_EMAIL_FROM` |
| `razorpay-webhook` | *(did not exist)* | HMAC signature | `RAZORPAY_WEBHOOK_SECRET` |

## The rule every function follows

**Identity comes from a verified JWT, never from the request body.** Every old PHP
endpoint trusted `$_POST['user_id']`, which is what allowed any client to read or modify
any other user's data. `_shared/auth.ts#requireUser` validates the token against the auth
server and returns a Supabase client scoped to that user, so **RLS still applies to
everything the function does**.

`serviceClient()` bypasses RLS and is used in exactly three places, each deliberate:
writing `orders` (no INSERT policy by design), validating a private coupon code, and the
admin data path. Never from a client, never before establishing who the caller is.

## Secrets

Set via **Dashboard → Edge Functions → Secrets**, or:

```bash
supabase secrets set GEMINI_API_KEY=...
```

| Secret | Used by | If unset |
|---|---|---|
| `GEMINI_API_KEY` | `process-chat` | Degrades to deterministic extraction only. Voice ordering still works for the common phrasings — it just stops handling messy input. |
| `RESEND_API_KEY`, `ORDER_EMAIL_FROM` | `send-order-email` | Order emails are skipped and logged. **Orders still place successfully.** |
| `ORDER_EMAIL_BCC` | `send-order-email` | No company copy. Optional. |
| `RAZORPAY_WEBHOOK_SECRET` | `razorpay-webhook` | **Fails closed** — rejects every webhook. An unverifiable payment notification must never be treated as genuine. |
| `ALLOWED_ORIGINS` | all | No `Access-Control-Allow-Origin` header is sent. Native Flutter clients are unaffected; browser callers are refused. Comma-separated list. |

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected
automatically — do not set them.

Note `send-order-email` uses Resend's HTTP API rather than SMTP, because Edge Functions
cannot open raw SMTP sockets. Keeping Gmail would need an SMTP relay in front.

## Deploying

`razorpay-webhook` **must** deploy with JWT verification off — Razorpay cannot present a
Supabase JWT, and the HMAC signature is the authentication. This is already declared in
`supabase/config.toml`.

```bash
supabase functions deploy                       # all, honouring config.toml
supabase functions deploy razorpay-webhook --no-verify-jwt   # if deploying individually
```

After deploying, register the webhook URL in the Razorpay dashboard and set the same
secret on both sides.

## Development

```bash
deno test --allow-all supabase/functions/_shared/intent_test.ts   # 16 tests
deno check supabase/functions/*/index.ts
deno lint supabase/functions/
deno fmt supabase/functions/
```

The intent tests are worth keeping green for a reason beyond correctness: every utterance
the deterministic extractor handles is a Gemini call not made. A regression there raises
spend silently while the feature still appears to work.
