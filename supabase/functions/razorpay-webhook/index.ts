// Razorpay payment webhook.
//
// The PHP backend had no webhook verification at all, which means anyone who knew the
// endpoint could mark any order paid. This verifies Razorpay's HMAC-SHA256 signature
// before touching an order.
//
// Public endpoint by necessity (Razorpay calls it), so it must be deployed with JWT
// verification disabled -- the signature IS the authentication:
//     supabase functions deploy razorpay-webhook --no-verify-jwt

import { serviceClient } from "../_shared/auth.ts";

const encoder = new TextEncoder();

/** Constant-time compare, so a timing side channel can't be used to forge a signature. */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function hmacHex(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  return Array.from(new Uint8Array(sig)).map((b) =>
    b.toString(16).padStart(2, "0")
  ).join("");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
  if (!secret) {
    // Fail closed. An unverifiable webhook must never be treated as genuine.
    console.error("RAZORPAY_WEBHOOK_SECRET not set; rejecting webhook.");
    return new Response("Not configured", { status: 500 });
  }

  const signature = req.headers.get("x-razorpay-signature");
  if (!signature) return new Response("Missing signature", { status: 400 });

  // Must hash the exact raw body; re-serializing parsed JSON would change the bytes.
  const raw = await req.text();
  const expected = await hmacHex(secret, raw);
  if (!timingSafeEqual(signature, expected)) {
    console.error("Razorpay signature mismatch; rejecting.");
    return new Response("Invalid signature", { status: 401 });
  }

  type RazorpayEvent = {
    event?: string;
    payload?: {
      payment?: {
        entity?: { amount?: number; notes?: { order_id?: string | number } };
      };
    };
  };

  let event: RazorpayEvent;
  try {
    event = JSON.parse(raw);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  // Razorpay retries on non-2xx, so respond 200 to anything we understood but don't act on.
  const kind = String(event?.event ?? "");
  const entity = event?.payload?.payment?.entity ?? {};
  const orderId = Number(entity?.notes?.order_id);

  if (!Number.isFinite(orderId)) {
    console.warn("Razorpay event without a usable notes.order_id:", kind);
    return new Response("ok", { status: 200 });
  }

  const admin = serviceClient();
  try {
    if (kind === "payment.captured") {
      // Amount is in paise and is authoritative from Razorpay; compare against what we
      // computed at placement so a mismatch is visible rather than silently accepted.
      const { data: order } = await admin
        .from("orders").select("id, final_amount, status").eq("id", orderId)
        .maybeSingle();
      if (!order) {
        console.warn("Webhook for unknown order", orderId);
        return new Response("ok", { status: 200 });
      }
      const paid = Number(entity.amount ?? 0) / 100;
      if (Math.abs(paid - Number(order.final_amount)) > 0.01) {
        console.error(
          `Amount mismatch on order ${orderId}: paid ${paid}, expected ${order.final_amount}`,
        );
      }
      await admin.from("orders").update({ status: "packed" }).eq("id", orderId);
    } else if (kind === "payment.failed") {
      await admin.from("orders").update({ status: "cancelled" }).eq(
        "id",
        orderId,
      );
    }
    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error(
      "razorpay-webhook failed:",
      e instanceof Error ? e.message : e,
    );
    // 500 so Razorpay retries a genuine processing failure.
    return new Response("error", { status: 500 });
  }
});
