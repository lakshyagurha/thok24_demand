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
  /**
   * One value per checkout attempt, reused on retry. Without it a dropped response --
   * routine on the mobile networks this app targets -- makes the client show "could not
   * place the order", and the customer's retry creates a second real order.
   */
  idempotency_key?: string | null;
};

const ALLOWED_PAYMENT = new Set(["COD", "RAZORPAY"]);

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * `%` and `_` are wildcards to ILIKE. The coupon box is free text, so without escaping
 * them a customer could type `DAS%` and match -- and redeem -- a status='Private' coupon
 * they were never given, which is exactly what RLS hiding those rows is meant to prevent.
 * Escaping leaves the lookup case-insensitive (matching the unique index on
 * lower(code_name)) while making it an exact match on the literal text.
 */
const escapeLike = (s: string) => s.replace(/[\\%_]/g, (c) => `\\${c}`);

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

  const idempotencyKey = body.idempotency_key?.trim() || null;
  if (idempotencyKey && !UUID_RE.test(idempotencyKey)) {
    return json(
      { success: false, message: "Invalid idempotency key" },
      400,
      req,
    );
  }

  /** Shapes an already-committed order row into this function's success response. */
  // deno-lint-ignore no-explicit-any
  const existingOrderResponse = (o: any) =>
    json(
      {
        success: true,
        order_id: o.id,
        order_datetime: o.order_datetime,
        total_amount: Number(o.total_amount),
        discount_amount: Number(o.discount_amount),
        delivery_charge: Number(o.delivery_charge),
        handling_charge: Number(o.handling_charge),
        final_amount: Number(o.final_amount),
        idempotent_replay: true,
      },
      200,
      req,
    );

  const ORDER_COLS =
    "id, order_datetime, total_amount, discount_amount, delivery_charge, handling_charge, final_amount";

  try {
    // --- 0. Idempotency: has this exact attempt already succeeded? ----------
    if (idempotencyKey) {
      const { data: prior } = await serviceClient()
        .from("orders")
        .select(ORDER_COLS)
        .eq("user_id", userId)
        .eq("idempotency_key", idempotencyKey)
        .maybeSingle();
      if (prior) return existingOrderResponse(prior);
    }

    // --- 1. Cart, read through the caller's own RLS context ----------------
    // Prices come from product_variants here, never from the request.
    type CartRow = {
      id: number;
      product_id: number;
      variant_id: number | null;
      quantity: number;
      image_url: string | null;
      product_variants: { selling_price: number; stock: number; name: string } | null;
      products: { name: string } | null;
    };

    const { data: cart, error: cartErr } = await db
      .from("cart_items")
      .select(
        "id, product_id, variant_id, quantity, image_url, " +
          "product_variants!inner(selling_price, stock, name), products!inner(name)",
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

    // A cheap read-only pass purely so the customer gets a message naming the item that
    // is short. It is NOT the safety check -- reserve_stock below is, because only the
    // conditional UPDATE inside it is atomic against a concurrent order.
    const short = cart.find((r) =>
      r.product_variants != null &&
      Number(r.product_variants.stock) < Number(r.quantity)
    );
    if (short) {
      const label = [short.products?.name, short.product_variants?.name]
        .filter(Boolean).join(" ");
      const available = Number(short.product_variants?.stock ?? 0);
      return json(
        {
          success: false,
          message: available <= 0
            ? `${label || "An item in your cart"} is out of stock. Please remove it to continue.`
            : `Only ${available} left of ${label || "an item in your cart"}. Please reduce the quantity.`,
        },
        409,
        req,
      );
    }

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
    let appliedCouponId: number | null = null;
    const requestedCode = body.coupon_code?.trim();
    if (requestedCode) {
      if (requestedCode.length > 64) {
        return json(
          { success: false, message: "Invalid coupon code" },
          400,
          req,
        );
      }
      const admin = serviceClient();
      const { data: coupon, error: couponErr } = await admin
        .from("coupon")
        .select(
          "id, code_name, discount, min_amount, expiry_date, status, usage_limit, per_user_limit",
        )
        .ilike("code_name", escapeLike(requestedCode))
        .maybeSingle();

      // Previously discarded. A malformed query or a multi-row match used to be
      // indistinguishable from "no such coupon", which hid real faults.
      if (couponErr) throw couponErr;

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

      // Redemption limits. Both columns are nullable and null means unlimited, so every
      // pre-existing coupon behaves exactly as it did before.
      if (coupon.usage_limit != null) {
        const { count, error } = await admin
          .from("coupon_redemptions")
          .select("id", { count: "exact", head: true })
          .eq("coupon_id", coupon.id);
        if (error) throw error;
        if ((count ?? 0) >= Number(coupon.usage_limit)) {
          return json(
            { success: false, message: "This coupon has been fully redeemed" },
            400,
            req,
          );
        }
      }
      if (coupon.per_user_limit != null) {
        const { count, error } = await admin
          .from("coupon_redemptions")
          .select("id", { count: "exact", head: true })
          .eq("coupon_id", coupon.id)
          .eq("user_id", userId);
        if (error) throw error;
        if ((count ?? 0) >= Number(coupon.per_user_limit)) {
          return json(
            { success: false, message: "You have already used this coupon" },
            400,
            req,
          );
        }
      }

      // `discount` is a percentage in the source data; never let it exceed the subtotal.
      discountAmount = money(
        Math.min(subtotal * (Number(coupon.discount) / 100), subtotal),
      );
      appliedCoupon = coupon.code_name;
      appliedCouponId = coupon.id;
    }

    const finalAmount = money(
      subtotal - discountAmount + deliveryCharge + handlingCharge,
    );

    // --- 4. Write the order ------------------------------------------------
    // Service role, because `orders` intentionally has no INSERT policy. user_id is the
    // verified JWT subject, so this cannot be pointed at another account.
    const admin = serviceClient();

    // Decrement stock first, atomically. The whole RPC is one transaction and each
    // UPDATE carries `stock >= quantity` in its WHERE clause, so two concurrent orders
    // for the last unit cannot both succeed -- the loser matches zero rows and raises.
    const stockItems = lines
      .filter((l) => l.variant_id != null)
      .map((l) => ({ variant_id: l.variant_id, quantity: l.quantity }));
    if (stockItems.length > 0) {
      const { error: stockErr } = await admin.rpc("reserve_stock", {
        p_items: stockItems,
      });
      if (stockErr) {
        if (String(stockErr.message ?? "").includes("INSUFFICIENT_STOCK")) {
          return json(
            {
              success: false,
              message:
                "Someone just took the last of one of your items. Please review your cart.",
            },
            409,
            req,
          );
        }
        throw stockErr;
      }
    }

    /** Puts back everything reserve_stock took, for any failure after reservation. */
    const releaseStock = async () => {
      if (stockItems.length === 0) return;
      const { error } = await admin.rpc("release_stock", { p_items: stockItems });
      if (error) {
        console.error(
          "release_stock failed; stock may be understated:",
          error.message,
        );
      }
    };

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
        idempotency_key: idempotencyKey,
      })
      .select(ORDER_COLS)
      .single();

    if (orderErr) {
      await releaseStock();
      // 23505 on (user_id, idempotency_key) means a concurrent retry of this same
      // attempt won the race. That is a success, not a failure -- return its order.
      if (orderErr.code === "23505" && idempotencyKey) {
        const { data: winner } = await admin
          .from("orders")
          .select(ORDER_COLS)
          .eq("user_id", userId)
          .eq("idempotency_key", idempotencyKey)
          .maybeSingle();
        if (winner) return existingOrderResponse(winner);
      }
      throw orderErr;
    }

    const { error: itemsErr } = await admin
      .from("order_items")
      .insert(lines.map((l) => ({ ...l, order_id: order.id })));
    if (itemsErr) {
      // No transaction spans these two inserts, so an orphaned order would otherwise
      // linger and be billable. Remove it; order_items cascades.
      await admin.from("orders").delete().eq("id", order.id);
      await releaseStock();
      throw itemsErr;
    }

    // Record the redemption so usage_limit / per_user_limit can be counted. Unique on
    // order_id, so an idempotent replay can never double-count against a limit.
    if (appliedCouponId != null) {
      const { error: redemptionErr } = await admin
        .from("coupon_redemptions")
        .insert({
          coupon_id: appliedCouponId,
          user_id: userId,
          order_id: order.id,
        });
      if (redemptionErr) {
        console.error(
          `coupon redemption not recorded for order ${order.id}:`,
          redemptionErr.message,
        );
      }
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

      // Only the rows this order actually consumed. The previous `.neq("id", -1)` swept
      // the whole cart, including anything added between the read above and this line --
      // silently discarding items the customer had not ordered yet. Still through the
      // caller's client, so RLS keeps it to their own rows.
      await db
        .from("cart_items")
        .delete()
        .in("id", cart.map((r) => r.id));
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
