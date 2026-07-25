// Send SMS Auth Hook -> MSG91.
//
// MSG91 is NOT one of Supabase's built-in phone providers (Twilio, MessageBird, Vonage,
// TextLocal). The supported way to use it is this hook: Supabase Auth generates the OTP
// and POSTs it here; we deliver it through MSG91's Flow API. The app code
// (dx_mart/lib/data/auth_repository.dart) is unchanged and provider-agnostic -- it still
// just calls signInWithOtp(phone:) / verifyOTP(). Swapping providers later means editing
// only this function, nothing in the app.
//
// Deploy with JWT verification OFF: Auth calls this server-side with a Standard Webhooks
// signature, not a user JWT. If "Enforce JWT" is left on, Auth's request is rejected at
// the gateway before it ever reaches this code.
//   supabase functions deploy send-sms-hook --no-verify-jwt
//   (or toggle it off in Dashboard -> Edge Functions -> send-sms-hook -> Details)
//
// The signature IS the authentication here -- that is why turning JWT off is safe.
//
// Required secrets (set under Edge Functions -> Secrets). Every one is checked below and
// the function fails closed without them, so an OTP is never silently dropped:
//   SEND_SMS_HOOK_SECRET  -- shown when you enable the hook; format "v1,whsec_...."
//   MSG91_AUTHKEY         -- MSG91 Dashboard -> API -> Configure
//   MSG91_SENDER_ID       -- your DLT-approved 6-char sender/header (e.g. THOK24)
//   MSG91_FLOW_ID         -- the Flow/Template id created from the DLT OTP template
//   MSG91_OTP_VAR         -- optional; the flow's variable name for the code. Default
//                            "OTP", i.e. a template reading "...code is ##OTP##...".
//                            Must match the flow EXACTLY (case-sensitive).

import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

const HOOK_SECRET = Deno.env.get("SEND_SMS_HOOK_SECRET") ?? "";
const AUTHKEY = Deno.env.get("MSG91_AUTHKEY") ?? "";
const SENDER = Deno.env.get("MSG91_SENDER_ID") ?? "";
const FLOW_ID = Deno.env.get("MSG91_FLOW_ID") ?? "";
const OTP_VAR = Deno.env.get("MSG91_OTP_VAR") ?? "OTP";

// https, never http: the authkey and the OTP must not cross the wire in cleartext.
const MSG91_FLOW_URL = "https://api.msg91.com/api/v5/flow/";

function fail(message: string, code = 500): Response {
  // The hook contract: empty 200 = sent; any 4xx/5xx with this shape = not sent, and
  // Auth surfaces the failure to the caller (better than pretending an OTP went out).
  return new Response(
    JSON.stringify({ error: { http_code: code, message } }),
    { status: code, headers: { "Content-Type": "application/json" } },
  );
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return fail("Method not allowed", 405);

  if (!HOOK_SECRET || !AUTHKEY || !SENDER || !FLOW_ID) {
    console.error(
      "send-sms-hook is missing configuration (need SEND_SMS_HOOK_SECRET, " +
        "MSG91_AUTHKEY, MSG91_SENDER_ID, MSG91_FLOW_ID); refusing to send.",
    );
    return fail("SMS sending is not configured", 500);
  }

  const raw = await req.text();

  // Verify the Standard Webhooks signature. This proves the request genuinely came from
  // Supabase Auth; without it, a public function URL could be driven to spend SMS credit.
  let user: { phone?: string };
  let sms: { otp?: string };
  try {
    const wh = new Webhook(HOOK_SECRET.replace("v1,whsec_", ""));
    const parsed = wh.verify(raw, {
      "webhook-id": req.headers.get("webhook-id") ?? "",
      "webhook-timestamp": req.headers.get("webhook-timestamp") ?? "",
      "webhook-signature": req.headers.get("webhook-signature") ?? "",
    }) as { user: { phone?: string }; sms: { otp?: string } };
    user = parsed.user;
    sms = parsed.sms;
  } catch (e) {
    console.error(
      "send-sms-hook signature verification failed:",
      e instanceof Error ? e.message : e,
    );
    return fail("Invalid signature", 401);
  }

  // MSG91 wants a bare country-code number (919XXXXXXXXX); Auth gives E.164 (+919...).
  const phone = (user?.phone ?? "").replace(/\D/g, "");
  const otp = sms?.otp ?? "";
  if (!phone || !otp) return fail("Missing phone or otp in hook payload", 400);

  try {
    const res = await fetch(MSG91_FLOW_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", authkey: AUTHKEY },
      body: JSON.stringify({
        flow_id: FLOW_ID,
        sender: SENDER,
        recipients: [{ mobiles: phone, [OTP_VAR]: otp }],
      }),
      signal: AbortSignal.timeout(10_000),
    });

    const bodyText = await res.text();
    // MSG91 sometimes returns HTTP 200 with { "type": "error", ... }, so check both.
    let ok = res.ok;
    try {
      const j = JSON.parse(bodyText);
      if (j?.type && String(j.type).toLowerCase() !== "success") ok = false;
    } catch {
      // Non-JSON body: fall back to the HTTP status alone.
    }
    if (!ok) {
      console.error("MSG91 rejected the send:", res.status, bodyText.slice(0, 300));
      return fail("Failed to send SMS via MSG91", 500);
    }
  } catch (e) {
    console.error(
      "send-sms-hook: MSG91 call failed:",
      e instanceof Error ? e.message : e,
    );
    return fail("Failed to reach MSG91", 500);
  }

  // Empty 200 == success, per the Send SMS hook contract.
  return new Response(null, { status: 200 });
});
