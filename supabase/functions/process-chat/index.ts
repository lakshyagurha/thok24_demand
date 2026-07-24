// BolKeOrder chat/voice endpoint. Port of Backend/api_folder/bot/process_chat.php.
//
// Architecture preserved: cheap deterministic matching first, Gemini only as a fallback,
// resolved against the hand-built product_aliases vocabulary, with repeat-order recall
// from regular_orders. Replies keep the "Ramu Bhai" persona and wording verbatim so the
// UX does not shift under the user.
//
// What changed, and why:
//   * Identity comes from the verified JWT. The PHP took user_id from the request body,
//     so any client could drive any other user's cart.
//   * All database work runs through the CALLER's client, so RLS applies. This function
//     never needs the service-role key.
//   * Deterministic extraction now runs BEFORE Gemini rather than only when the API key
//     is missing, so most utterances cost no LLM call.
//   * The debug_gemini_raw / debug_response_data fields are gone. They leaked the raw
//     upstream response to the client.
//   * Cart rows store the image PATH, not a fully-built URL. The PHP baked the serving
//     host into the row, which is why live data contains localhost and 192.168.31.10.

import { json, preflight } from "../_shared/cors.ts";
import { requireUser } from "../_shared/auth.ts";
import {
  extractIntents,
  type Intent,
  isBillIntent,
  isConfirmIntent,
  isRegularIntent,
} from "../_shared/intent.ts";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

const GEMINI_MODEL = "gemini-2.5-flash";

type CartLine = {
  id: number;
  product_id: number;
  variant_id: number;
  name: string;
  product_name: string;
  variant_name: string;
  price: number;
  selling_price: number;
  quantity: number;
  image_url: string;
};

/** Charges come from app_settings; the fallbacks are the constants the PHP hardcoded. */
async function charges(db: SupabaseClient, subtotal: number) {
  const { data } = await db.from("app_settings").select("key, value");
  const get = (k: string, fallback: number) => {
    const row = data?.find((r) => r.key === k);
    const n = row ? Number(row.value) : NaN;
    return Number.isFinite(n) ? n : fallback;
  };
  const handling = get("handling_charge", 5);
  const threshold = get("free_delivery_threshold", 500);
  const delivery = subtotal < threshold ? get("delivery_charge", 10) : 0;
  return { handling, delivery, final: subtotal + handling + delivery };
}

async function loadCart(
  db: SupabaseClient,
): Promise<{ items: CartLine[]; subtotal: number }> {
  type CartRow = {
    id: number;
    product_id: number;
    variant_id: number;
    quantity: number;
    image_url: string | null;
    products: { name: string } | null;
    product_variants:
      | { name: string; price: number; selling_price: number }
      | null;
  };

  // RLS restricts this to the caller's own rows; no user_id filter needed or trusted.
  const { data, error } = await db
    .from("cart_items")
    .select(
      "id, product_id, variant_id, quantity, image_url, " +
        "products!inner(name), product_variants!inner(name, price, selling_price)",
    )
    .returns<CartRow[]>();
  if (error) throw error;

  let subtotal = 0;
  const items: CartLine[] = (data ?? []).map((r) => {
    const price = Number(r.product_variants?.price ?? 0);
    const selling = Number(r.product_variants?.selling_price ?? 0);
    subtotal += selling * Number(r.quantity);
    return {
      id: r.id,
      product_id: r.product_id,
      variant_id: r.variant_id,
      name: r.products?.name ?? "",
      product_name: r.products?.name ?? "",
      variant_name: r.product_variants?.name ?? "",
      price,
      selling_price: selling,
      quantity: r.quantity,
      image_url: r.image_url ?? "",
    };
  });
  return { items, subtotal };
}

async function saveMessage(
  db: SupabaseClient,
  userId: string,
  role: "user" | "bot",
  message: string,
) {
  // Best-effort: a chat-log failure must not cost the user their order.
  const { error } = await db.from("chat_messages").insert({
    user_id: userId,
    role,
    message,
  });
  if (error) console.error("chat_messages insert failed:", error.message);
}

/** Fallback only. Called when deterministic extraction finds nothing. */
async function geminiExtract(message: string): Promise<Intent[]> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) {
    console.warn("GEMINI_API_KEY not set; deterministic extraction only.");
    return [];
  }

  const prompt =
    `You are a grocery intent extraction bot. Extract the grocery items the user wants ` +
    `to order from this message: '${message}'.\n` +
    `Output ONLY a valid JSON array of objects with keys: 'product_name', 'quantity' ` +
    `(integer), 'unit' (string). No markdown, no backticks.`;

  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
      {
        method: "POST",
        // Key in a header, not the query string, so it stays out of request logs.
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
        signal: AbortSignal.timeout(10_000),
      },
    );
    if (!res.ok) {
      console.error("Gemini HTTP", res.status);
      return [];
    }
    const body = await res.json();
    const text: string | undefined = body?.candidates?.[0]?.content?.parts?.[0]
      ?.text;
    if (!text) return [];

    const cleaned = text.replaceAll("```json", "").replaceAll("```", "").trim();
    const parsed = JSON.parse(cleaned);
    if (!Array.isArray(parsed)) return [];

    return parsed
      .filter((i) => i && typeof i.product_name === "string")
      .map((i) => ({
        product_name: String(i.product_name),
        quantity: Number(i.quantity) > 0 ? Number(i.quantity) : 1,
        unit: String(i.unit ?? ""),
      }));
  } catch (e) {
    // A dead or slow LLM must degrade to "I didn't understand", never a 500.
    console.error("Gemini call failed:", e instanceof Error ? e.message : e);
    return [];
  }
}

/** Resolves a spoken name to a product+variant via the alias vocabulary. */
async function matchProduct(db: SupabaseClient, spoken: string) {
  const token = spoken.trim().toLowerCase();

  type AliasRow = { product_id: number; products: { name: string } | null };

  const { data: alias } = await db
    .from("product_aliases")
    .select("product_id, products!inner(name)")
    .ilike("alias", `%${token}%`)
    .limit(1)
    .maybeSingle()
    .returns<AliasRow>();

  let productId: number | null = alias?.product_id ?? null;
  let productName: string = alias?.products?.name ?? "";

  if (!productId) {
    // Fall back to the catalog itself, matching Hindi and Hinglish name columns too --
    // the PHP only ever matched the English `name`.
    const { data: prod } = await db
      .from("products")
      .select("id, name")
      .or(
        `name.ilike.%${token}%,name_hi.ilike.%${token}%,name_hn.ilike.%${token}%`,
      )
      .limit(1)
      .maybeSingle();
    if (!prod) return null;
    productId = prod.id;
    productName = prod.name;
  }

  // Cheapest variant, so a vague "aata" doesn't silently pick the priciest pack.
  const { data: variant } = await db
    .from("product_variants")
    .select("id, price, selling_price")
    .eq("product_id", productId)
    .order("selling_price", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (!variant) return null;

  const { data: image } = await db
    .from("product_images")
    .select("image_url")
    .eq("product_id", productId)
    .limit(1)
    .maybeSingle();

  return {
    product_id: productId!,
    product_name: productName,
    variant_id: variant.id,
    price: Number(variant.price),
    selling_price: Number(variant.selling_price),
    image_url: image?.image_url ?? "",
  };
}

async function addToCart(
  db: SupabaseClient,
  userId: string,
  m: NonNullable<Awaited<ReturnType<typeof matchProduct>>>,
  qty: number,
): Promise<CartLine> {
  const { data: existing } = await db
    .from("cart_items")
    .select("id, quantity")
    .eq("product_id", m.product_id)
    .eq("variant_id", m.variant_id)
    .maybeSingle();

  let cartId: number;
  let quantity: number;
  if (existing) {
    quantity = Number(existing.quantity) + qty;
    const { error } = await db.from("cart_items").update({ quantity }).eq(
      "id",
      existing.id,
    );
    if (error) throw error;
    cartId = existing.id;
  } else {
    quantity = qty;
    const { data, error } = await db
      .from("cart_items")
      .insert({
        user_id: userId,
        product_id: m.product_id,
        variant_id: m.variant_id,
        quantity: qty,
        image_url: m.image_url,
      })
      .select("id")
      .single();
    if (error) throw error;
    cartId = data.id;
  }

  return {
    id: cartId,
    product_id: m.product_id,
    variant_id: m.variant_id,
    name: m.product_name,
    product_name: m.product_name,
    variant_name: "",
    price: m.price,
    selling_price: m.selling_price,
    quantity,
    image_url: m.image_url,
  };
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;

  const caller = await requireUser(req);
  if (!caller) {
    return json({ success: false, message: "Unauthorized" }, 401, req);
  }
  const { id: userId, client: db } = caller;

  let message: string;
  try {
    const body = await req.json();
    message = String(body?.message ?? "").trim();
  } catch {
    return json({ success: false, message: "Invalid JSON body" }, 400, req);
  }
  if (!message) {
    return json({ success: false, message: "Missing message" }, 400, req);
  }

  try {
    await saveMessage(db, userId, "user", message);

    // --- 1. Show the bill / parchi ---------------------------------------
    if (isBillIntent(message)) {
      const { items, subtotal } = await loadCart(db);
      if (items.length === 0) {
        const reply =
          "Didi, abhi aapki parchi khali hai. Kuch mangvana ho toh boliye! 🛍️";
        await saveMessage(db, userId, "bot", reply);
        return json(
          { success: true, reply, items: [], message_type: "text" },
          200,
          req,
        );
      }
      const c = await charges(db, subtotal);
      const reply = "Ji Didi, ye raha aapka bill/parchi. Sab sahi hai na?";
      await saveMessage(db, userId, "bot", reply);
      return json(
        {
          success: true,
          reply,
          items,
          message_type: "cartSummary",
          subtotal,
          final_amount: c.final,
        },
        200,
        req,
      );
    }

    // --- 2. Confirm / checkout -------------------------------------------
    if (isConfirmIntent(message)) {
      const { items, subtotal } = await loadCart(db);
      if (items.length === 0) {
        const reply =
          "Didi, abhi aapki parchi khali hai. Kuch add karne ko boliye, jaise '2 kilo aata bhej do'. 😊";
        await saveMessage(db, userId, "bot", reply);
        return json(
          { success: true, reply, items: [], message_type: "text" },
          200,
          req,
        );
      }
      const c = await charges(db, subtotal);
      const reply =
        "Didi, maine checkout page khol diya hai. Apni details verify karke order place kar lijiye! 🛍️";
      await saveMessage(db, userId, "bot", reply);
      return json(
        {
          success: true,
          reply,
          items,
          message_type: "checkout",
          subtotal,
          final_amount: c.final,
        },
        200,
        req,
      );
    }

    // --- 3. Extract order intents: cheap path first ----------------------
    let intents = extractIntents(message);
    const usedLlm = intents.length === 0;
    if (usedLlm) intents = await geminiExtract(message);

    // --- 4. Nothing understood: "the usual", else apologise --------------
    if (intents.length === 0) {
      if (isRegularIntent(message)) {
        type RegularRow = {
          product_id: number;
          variant_id: number;
          products: { name: string } | null;
          product_variants: { price: number; selling_price: number } | null;
        };

        const { data: regulars } = await db
          .from("regular_orders")
          .select(
            "product_id, variant_id, products!inner(name), product_variants!inner(price, selling_price)",
          )
          .order("frequency_score", { ascending: false })
          .limit(5)
          .returns<RegularRow[]>();

        const added: CartLine[] = [];
        for (const r of regulars ?? []) {
          const { data: image } = await db
            .from("product_images").select("image_url").eq(
              "product_id",
              r.product_id,
            ).limit(1).maybeSingle();
          added.push(
            await addToCart(db, userId, {
              product_id: r.product_id,
              product_name: r.products?.name ?? "",
              variant_id: r.variant_id,
              price: Number(r.product_variants?.price ?? 0),
              selling_price: Number(r.product_variants?.selling_price ?? 0),
              image_url: image?.image_url ?? "",
            }, 1),
          );
        }

        const reply = added.length > 0
          ? "Aapka regular order cart mein add kar diya gaya hai. Kuch aur chahiye?"
          : "Didi, abhi tak koi regular order nahi mila. Pehli baar kya mangvana hai?";
        await saveMessage(db, userId, "bot", reply);
        return json(
          { success: true, reply, items: added, message_type: "text" },
          200,
          req,
        );
      }

      const reply =
        "Maaf karna, main samajh nahi paya. Kripya quantity ke saath product ka naam likhein. Jaise: '2 kilo aata'.";
      await saveMessage(db, userId, "bot", reply);
      return json(
        { success: true, reply, items: [], message_type: "text" },
        200,
        req,
      );
    }

    // --- 5. Resolve each intent and add to cart --------------------------
    const added: CartLine[] = [];
    const failed: string[] = [];
    for (const intent of intents) {
      const match = await matchProduct(db, intent.product_name);
      if (!match) {
        failed.push(intent.product_name);
        continue;
      }
      added.push(
        await addToCart(
          db,
          userId,
          match,
          Math.max(1, Math.round(intent.quantity)),
        ),
      );
    }

    let reply = "";
    if (added.length > 0) {
      reply += "Ji, maine cart mein add kar diya hai: " +
        added.map((p) => `${p.quantity} ${p.name}`).join(", ") + ". ";
    }
    if (failed.length > 0) {
      reply += "Lekin mujhe ye items nahi mile: " + failed.join(", ") + ". ";
    }
    if (reply === "") {
      reply = "Maaf karna, mujhe aapki request samajh nahi aayi.";
    }

    await saveMessage(db, userId, "bot", reply);
    return json(
      { success: true, reply, items: added, message_type: "text" },
      200,
      req,
    );
  } catch (e) {
    console.error("process-chat failed:", e instanceof Error ? e.message : e);
    return json({ success: false, message: "Something went wrong" }, 500, req);
  }
});
