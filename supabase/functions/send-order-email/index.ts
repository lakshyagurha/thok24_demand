// Order confirmation email. Replaces send_email_background.php (PHPMailer over Gmail SMTP
// with the App Password hardcoded in source).
//
// Called server-to-server by place-order with the service-role key, never by a client:
// it takes an order_id and reads the order itself, so it cannot be used to spray mail at
// arbitrary addresses or to enumerate orders.
//
// Deno Edge Functions cannot open raw SMTP sockets, so this uses Resend's HTTP API rather
// than SMTP. If you would rather keep Gmail, that needs an SMTP relay service in front.

import { serviceClient } from "../_shared/auth.ts";

const RESEND_ENDPOINT = "https://api.resend.com/emails";

function rupees(n: number): string {
  return `₹${Number(n).toFixed(2)}`;
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!
  ));
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Only the service-role key may invoke this.
  const auth = req.headers.get("Authorization") ?? "";
  const expected = `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`;
  if (auth !== expected) return new Response("Unauthorized", { status: 401 });

  const apiKey = Deno.env.get("RESEND_API_KEY");
  const fromAddress = Deno.env.get("ORDER_EMAIL_FROM");
  const companyEmail = Deno.env.get("ORDER_EMAIL_BCC");
  if (!apiKey || !fromAddress) {
    // Not fatal: place-order already succeeded and must not be rolled back over email.
    console.error(
      "RESEND_API_KEY / ORDER_EMAIL_FROM not set; skipping order email.",
    );
    return new Response(
      JSON.stringify({ sent: false, reason: "not configured" }),
      { status: 200 },
    );
  }

  let orderId: number;
  try {
    orderId = Number((await req.json())?.order_id);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }
  if (!Number.isFinite(orderId)) {
    return new Response("order_id required", { status: 400 });
  }

  const admin = serviceClient();

  // Shape declared explicitly: supabase-js cannot infer through the nested
  // order_items -> products embed and falls back to an error union.
  type OrderRow = {
    id: number;
    total_amount: number;
    discount_amount: number;
    delivery_charge: number;
    handling_charge: number;
    final_amount: number;
    payment_method: string;
    order_datetime: string;
    delivery_date: string | null;
    delivery_time_window: string | null;
    user_id: string;
    order_items: Array<{
      quantity: number;
      unit_price: number | null;
      products: { name: string; name_hi: string | null } | null;
    }>;
  };

  const { data: order, error } = await admin
    .from("orders")
    .select(
      "id, total_amount, discount_amount, delivery_charge, handling_charge, final_amount, " +
        "payment_method, order_datetime, delivery_date, delivery_time_window, user_id, " +
        "order_items(quantity, unit_price, products(name, name_hi))",
    )
    .eq("id", orderId)
    .maybeSingle()
    .returns<OrderRow>();

  if (error || !order) {
    console.error("send-order-email: order not found", orderId, error?.message);
    return new Response(
      JSON.stringify({ sent: false, reason: "order not found" }),
      { status: 200 },
    );
  }

  // Recipient is resolved from the order's owner, never from the request.
  const { data: userRes } = await admin.auth.admin.getUserById(order.user_id);
  const to = userRes?.user?.email;
  if (!to) {
    // Expected for phone/OTP accounts with no email on file. Not an error.
    console.warn(
      `Order ${orderId}: no email on the account; skipping confirmation.`,
    );
    return new Response(
      JSON.stringify({ sent: false, reason: "no email on account" }),
      { status: 200 },
    );
  }

  const items = order.order_items ?? [];
  const rows = items.map((i) => {
    const en = i.products?.name ?? "Item";
    const hi = i.products?.name_hi;
    const label = hi
      ? `${escapeHtml(en)} <span style="color:#666">(${escapeHtml(hi)})</span>`
      : escapeHtml(en);
    const line = i.unit_price != null
      ? rupees(Number(i.unit_price) * Number(i.quantity))
      : "-";
    return `<tr><td style="padding:6px 0">${label}</td><td align="center">${i.quantity}</td><td align="right">${line}</td></tr>`;
  }).join("");

  const html = `
    <div style="font-family:system-ui,sans-serif;max-width:560px;margin:0 auto">
      <h2 style="margin:0 0 4px">Order #${order.id} confirmed</h2>
      <p style="color:#555;margin:0 0 16px">आपका ऑर्डर मिल गया है — धन्यवाद!</p>
      <table width="100%" style="border-collapse:collapse;font-size:14px">
        <thead>
          <tr style="border-bottom:1px solid #ddd;text-align:left">
            <th style="padding:6px 0">Item</th><th align="center">Qty</th><th align="right">Amount</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
      <hr style="border:none;border-top:1px solid #eee;margin:16px 0">
      <table width="100%" style="font-size:14px">
        <tr><td>Subtotal</td><td align="right">${
    rupees(order.total_amount)
  }</td></tr>
        ${
    Number(order.discount_amount) > 0
      ? `<tr><td>Discount</td><td align="right">-${
        rupees(order.discount_amount)
      }</td></tr>`
      : ""
  }
        <tr><td>Delivery</td><td align="right">${
    rupees(order.delivery_charge)
  }</td></tr>
        <tr><td>Handling</td><td align="right">${
    rupees(order.handling_charge)
  }</td></tr>
        <tr style="font-weight:600;font-size:16px">
          <td style="padding-top:8px">Total</td>
          <td align="right" style="padding-top:8px">${
    rupees(order.final_amount)
  }</td>
        </tr>
      </table>
      <p style="color:#555;font-size:13px;margin-top:16px">
        Payment: ${escapeHtml(order.payment_method)}<br>
        ${
    order.delivery_date
      ? `Delivery: ${escapeHtml(order.delivery_date)} ${
        escapeHtml(order.delivery_time_window ?? "")
      }`
      : ""
  }
      </p>
    </div>`;

  try {
    const res = await fetch(RESEND_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromAddress,
        to: [to],
        ...(companyEmail ? { bcc: [companyEmail] } : {}),
        subject: `DxMart order #${order.id} confirmed`,
        html,
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) {
      console.error(
        "Resend rejected the message:",
        res.status,
        await res.text(),
      );
      return new Response(JSON.stringify({ sent: false }), { status: 200 });
    }
    return new Response(JSON.stringify({ sent: true }), { status: 200 });
  } catch (e) {
    console.error(
      "send-order-email failed:",
      e instanceof Error ? e.message : e,
    );
    return new Response(JSON.stringify({ sent: false }), { status: 200 });
  }
});
