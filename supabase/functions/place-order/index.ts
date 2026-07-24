// Order placement. Replaces Backend/api_folder/product_api_project/place_order/place_order.php.
//
// This function exists because RLS cannot solve the problem it solves. An RLS policy can
// prove *who you are*; it cannot prove *what you owe*. The PHP endpoint computed
// total_amount server-side but accepted discount_amount, delivery_charge,
// handling_charge and final_amount straight from the request body, so a client could
// submit an order for any price it liked. `orders` therefore has no INSERT policy at
// all, and every monetary field is recomputed here from the catalog.
//
// The client sends only: which address, when to deliver, payment method, gift note, and
// optionally a coupon code. Nothing about money is taken from the request.

import { json, preflight } from "../_shared/cors.ts";
import { requireUser, serviceClient } from "../_shared/auth.ts";

type Body = {
  delivery_address_id?: number;
  delivery_date?: string | null;
  delivery_time_window?: string | null;
  payment_method?: string;
  coupon_code?: string | null;
  gift?: string | null;
};

const ALLOWED_PAYMENT = new Set(["COD", "RAZORPAY"]);

/**
 * An online payment is only honestly offerable if the webhook that confirms it can
 * actually verify a signature. Without RAZORPAY_WEBHOOK_SECRET, razorpay-webhook fails
 * closed (correctly) -- which would leave the order stuck at 'pending' forever while the
 * customer believes they have paid. Refuse the method outright rather than take money we
 * cannot reconcile. Setting the secret enables online payment with no code change.
 */
function onlinePaymentAvailable(): boolean {
  return !!Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
}

/** Rounds to paise. Money is numeric(10,2) in the database; keep JS from drifting. */
const money = (n: number) => Math.round(n * 100) / 100;

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;

  const caller = await requireUser(req);
  if (!caller) {
    return json({ success: false, message: "Unauthorized" }, 401, req);
  }
  const { id: userId, client: db } = caller;

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return json({ success: false, message: "Invalid JSON body" }, 400, req);
  }

  const paymentMethod = String(body.payment_method ?? "COD").toUpperCase();
  if (!ALLOWED_PAYMENT.has(paymentMethod)) {
    return json(
      { success: false, message: "Unsupported payment method" },
      400,
      req,
    );
  }
  if (paymentMethod === "RAZORPAY" && !onlinePaymentAvailable()) {
    console.error(
      "RAZORPAY requested but RAZORPAY_WEBHOOK_SECRET is not set; refusing the order.",
    );
    return json(
      {
        success: false,
        message: "Online payment is unavailable right now. Please choose Cash on Delivery.",
      },
      400,
      req,
    );
  }

  try {
    // --- 1. Cart, read through the caller's own RLS context ----------------
    // Prices come from product_variants here, never from the request.
    type CartRow = {
      product_id: number;
      variant_id: number | null;
      quantity: number;
      image_url: string | null;
      product_variants: { selling_price: number } | null;
    };

    const { data: cart, error: cartErr } = await db
      .from("cart_items")
      .select(
        "product_id, variant_id, quantity, image_url, product_variants!inner(selling_price)",
      )
      .returns<CartRow[]>();
    if (cartErr) throw cartErr;
    if (!cart || cart.length === 0) {
      return json({ success: false, message: "Cart is empty" }, 400, req);
    }

    let subtotal = 0;
    const lines = cart.map((r) => {
      const unitPrice = Number(r.product_variants?.selling_price ?? 0);
      subtotal += unitPrice * Number(r.quantity);
      return {
        product_id: r.product_id,
        variant_id: r.variant_id,
        quantity: Number(r.quantity),
        unit_price: money(unitPrice),
        image_url: r.image_url,
      };
    });
    subtotal = money(subtotal);

    // --- 2. Address must belong to the caller ------------------------------
    // Selected through the caller's client, so RLS makes someone else's address
    // simply invisible rather than relying on a manual ownership check.
    let deliveryAddressId: number | null = null;
    if (body.delivery_address_id != null) {
      const { data: addr } = await db
        .from("delivery_address")
        .select("id")
        .eq("id", body.delivery_address_id)
        .maybeSingle();
      if (!addr) {
        return json(
          { success: false, message: "Delivery address not found" },
          400,
          req,
        );
      }
      deliveryAddressId = addr.id;
    }

    // --- 3. Settings and coupon, both resolved server-side -----------------
    const { data: settings } = await db.from("app_settings").select(
      "key, value",
    );
    const setting = (k: string, fallback: number) => {
      const row = settings?.find((r) => r.key === k);
      const n = row ? Number(row.value) : NaN;
      return Number.isFinite(n) ? n : fallback;
    };

    const handlingCharge = money(setting("handling_charge", 5));
    const freeDeliveryOver = setting("free_delivery_threshold", 500);
    const deliveryCharge = subtotal >= freeDeliveryOver
      ? 0
      : money(setting("delivery_charge", 10));
    const minimumOrder = setting("minimum_order_amount", 0);

    if (subtotal < minimumOrder) {
      return json(
        { success: false, message: `Minimum order amount is ${minimumOrder}` },
        400,
        req,
      );
    }

    // Coupon validation uses the service-role client on purpose: RLS hides
    // status='Private' coupons from clients, and a legitimately-held private code must
    // still redeem. The code is checked against the table, never trusted from input.
    let discountAmount = 0;
    let appliedCoupon: string | null = null;
    const requestedCode = body.coupon_code?.trim();
    if (requestedCode) {
      const admin = serviceClient();
      const { data: coupon } = await admin
        .from("coupon")
        .select("code_name, discount, min_amount, expiry_date, status")
        .ilike("code_name", requestedCode)
        .maybeSingle();

      if (!coupon) {
        return json(
          { success: false, message: "Invalid coupon code" },
          400,
          req,
        );
      }
      if (coupon.expiry_date && new Date(coupon.expiry_date) < new Date()) {
        return json(
          { success: false, message: "Coupon has expired" },
          400,
          req,
        );
      }
      if (subtotal < Number(coupon.min_amount ?? 0)) {
        return json(
          {
            success: false,
            message: `Coupon needs a minimum order of ${coupon.min_amount}`,
          },
          400,
          req,
        );
      }
      // `discount` is a percentage in the source data; never let it exceed the subtotal.
      discountAmount = money(
        Math.min(subtotal * (Number(coupon.discount) / 100), subtotal),
      );
      appliedCoupon = coupon.code_name;
    }

    const finalAmount = money(
      subtotal - discountAmount + deliveryCharge + handlingCharge,
    );

    // --- 4. Write the order ------------------------------------------------
    // Service role, because `orders` intentionally has no INSERT policy. user_id is the
    // verified JWT subject, so this cannot be pointed at another account.
    const admin = serviceClient();
    const { data: order, error: orderErr } = await admin
      .from("orders")
      .insert({
        user_id: userId,
        total_amount: subtotal,
        coupon_code: appliedCoupon,
        discount_amount: discountAmount,
        delivery_charge: deliveryCharge,
        handling_charge: handlingCharge,
        final_amount: finalAmount,
        status: "pending",
        payment_method: paymentMethod,
        delivery_date: body.delivery_date ?? null,
        delivery_time_window: body.delivery_time_window ?? null,
        delivery_address_id: deliveryAddressId,
        gift: body.gift ?? null,
      })
      .select("id, order_datetime")
      .single();
    if (orderErr) throw orderErr;

    const { error: itemsErr } = await admin
      .from("order_items")
      .insert(lines.map((l) => ({ ...l, order_id: order.id })));
    if (itemsErr) {
      // No transaction spans these two inserts, so an orphaned order would otherwise
      // linger and be billable. Remove it; order_items cascades.
      await admin.from("orders").delete().eq("id", order.id);
      throw itemsErr;
    }

    // --- 5. Repeat-order memory + clear the cart ---------------------------
    // The order and order_items rows above are already committed -- this function's
    // contract with the client is "the order exists", not "housekeeping succeeded". A
    // hiccup here must be logged, never turned into a false "Could not place order" that
    // would make the caller think nothing happened and place a duplicate.
    try {
      // regular_orders is read-only to clients precisely so this cannot be forged.
      for (const l of lines) {
        const { data: existing } = await admin
          .from("regular_orders")
          .select("id, frequency_score")
          .eq("user_id", userId)
          .eq("product_id", l.product_id)
          .eq("variant_id", l.variant_id)
          .maybeSingle();
        if (existing) {
          await admin
            .from("regular_orders")
            .update({
              frequency_score: existing.frequency_score + 1,
              last_ordered: new Date().toISOString(),
            })
            .eq("id", existing.id);
        } else {
          await admin.from("regular_orders").insert({
            user_id: userId,
            product_id: l.product_id,
            variant_id: l.variant_id,
            frequency_score: 1,
            last_ordered: new Date().toISOString(),
          });
        }
      }

      // Through the caller's client, so it can only ever empty their own cart.
      await db.from("cart_items").delete().neq("id", -1);
    } catch (e) {
      console.error(
        `post-order housekeeping failed for order ${order.id} (order still placed):`,
        e instanceof Error ? e.message : e,
      );
    }

    // --- 6. Confirmation email, strictly best-effort ------------------------
    // The PHP fired this with a 1-second timeout and ignored failures. Same intent here:
    // a mail outage must never fail an order that is already committed.
    try {
      await fetch(
        `${Deno.env.get("SUPABASE_URL")}/functions/v1/send-order-email`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${
              Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
            }`,
          },
          body: JSON.stringify({ order_id: order.id }),
          signal: AbortSignal.timeout(3000),
        },
      );
    } catch (e) {
      console.error(
        "order email dispatch failed (order still placed):",
        e instanceof Error ? e.message : e,
      );
    }

    return json(
      {
        success: true,
        order_id: order.id,
        order_datetime: order.order_datetime,
        total_amount: subtotal,
        discount_amount: discountAmount,
        delivery_charge: deliveryCharge,
        handling_charge: handlingCharge,
        final_amount: finalAmount,
      },
      200,
      req,
    );
  } catch (e) {
    console.error("place-order failed:", e instanceof Error ? e.message : e);
    return json({ success: false, message: "Could not place order" }, 500, req);
  }
});
