import { json, preflight } from "../_shared/cors.ts";
import { requireUser } from "../_shared/auth.ts";
import { chooseVariant } from "../_shared/units.ts";
import {
  findAlternatives,
  loadIndex,
  matchOne,
  renderForPrompt,
  type Variant,
} from "../_shared/catalog.ts";
import {
  matchOccasionBundle,
  resolveBundle,
} from "../_shared/bundles.ts";
import {
  extractIntents,
  type Intent,
  isBillIntent,
  isConfirmIntent,
  isRegularIntent,
} from "../_shared/intent.ts";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

const GEMINI_MODEL = "gemini-1.5-flash";

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

type GeminiAnalysis = {
  intent_type:
    | "ORDER"
    | "BUNDLE"
    | "GREETING"
    | "RECALL_REGULAR"
    | "SHOW_BILL"
    | "CHECKOUT"
    | "OFF_TOPIC"
    | "DISAMBIGUATE";
  reply: string;
  items?: { product_id: number; variant_id?: number; quantity?: number; unit?: string }[];
  candidate_product_ids?: number[];
};

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
  const { error } = await db.from("chat_messages").insert({
    user_id: userId,
    role,
    message,
  });
  if (error) console.error("chat_messages insert failed:", error.message);
}

function isGreetingIntent(msg: string): boolean {
  return /\b(halo|hello|hi|namaste|नमस्ते|हेलो|हाय|hlo|helo|hey|kya hal)\b/i.test(msg.trim());
}

async function geminiAnalyze(
  message: string,
  catalogPrompt: string,
  regularsPrompt: string,
  cartPrompt: string,
): Promise<GeminiAnalysis | null> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) return null;

  const systemPrompt =
    `You are "Ramu Bhai", the warm, helpful local Kirana shop owner at DxMart.\n` +
    `You speak respectfully ("Didi", "Bhaiya", "Ji bilkul"). You understand Hindi, Hinglish, Devanagari, and English.\n\n` +
    `YOUR TASK:\n` +
    `Analyze the customer's message against CATALOG, REGULAR ORDERS, and CART.\n` +
    `Select the INTENT_TYPE:\n` +
    `- "ORDER": Customer wants specific item(s) (e.g., "2 kg aata", "2 kilo aata", "1 litre tel", "oil and sugar", "chai"). Match to product_ids from CATALOG.\n` +
    `- "BUNDLE": Customer asks for occasion/festival/meal kits (e.g., "Ganesh Puja", "Diwali pooja kit", "Chai Nashta", "Monthly Ration", "biryani items"). Select matching product_ids from CATALOG.\n` +
    `- "RECALL_REGULAR": Customer asks for past purchases (e.g., "jo pichhle baar mangwaya tha", "wahi regular", "mera regular order", "pichla order", "wahi bhej do"). Select item product_ids from REGULAR ORDERS.\n` +
    `- "GREETING": Customer says hello, hi, namaste, casual greeting, or asks how Ramu Bhai is doing.\n` +
    `- "SHOW_BILL": Customer asks to see bill/parchi/hisaab.\n` +
    `- "CHECKOUT": Customer wants to confirm/place/checkout order.\n` +
    `- "OFF_TOPIC": Customer asks about non-grocery topics (sports, politics, trivia, coding, weather). Politely steer back to kirana shopping in character ("Didi/Bhaiya, main toh aapka Ramu Bhai hoon, ration aur kirana dukandar! Aaj ghar ke liye kya mangvana hai?").\n` +
    `- "DISAMBIGUATE": Customer asks for a broad product (e.g., "atta" or "tel") with multiple brand choices. Return candidate_product_ids.\n\n` +
    `Reply strictly with a valid JSON object only. Format:\n` +
    `{\n` +
    `  "intent_type": "ORDER|BUNDLE|GREETING|RECALL_REGULAR|SHOW_BILL|CHECKOUT|OFF_TOPIC|DISAMBIGUATE",\n` +
    `  "reply": "<Friendly Ramu Bhai response>",\n` +
    `  "items": [{"product_id": <number>, "quantity": <number>, "unit": "<string>"}],\n` +
    `  "candidate_product_ids": [<number>]\n` +
    `}\n\n` +
    `CATALOG:\n${catalogPrompt}\n\n` +
    `REGULAR ORDERS:\n${regularsPrompt}\n\n` +
    `CART:\n${cartPrompt}\n\n` +
    `CUSTOMER MESSAGE:\n"""\n${message}\n"""`;

  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({ contents: [{ parts: [{ text: systemPrompt }] }] }),
        signal: AbortSignal.timeout(10_000),
      },
    );
    if (!res.ok) {
      console.error("Gemini HTTP error:", res.status);
      return null;
    }
    const body = await res.json();
    const text: string | undefined = body?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) return null;

    const cleaned = text.replaceAll("```json", "").replaceAll("```", "").trim();
    return JSON.parse(cleaned) as GeminiAnalysis;
  } catch (e) {
    console.error("geminiAnalyze error:", e);
    return null;
  }
}

function resolveLine(
  match: {
    product_id: number;
    product_name: string;
    variants: Variant[];
    image_url: string;
  },
  quantity: number,
  spokenUnit?: string | null,
) {
  const choice = chooseVariant(match.variants, quantity, spokenUnit);
  if (!choice) return null;
  const v = choice.variant;
  return {
    product_id: match.product_id,
    product_name: match.product_name,
    variant_id: v.id,
    variant_name: v.name ?? "",
    price: Number((v as { price?: number | string }).price ?? 0),
    selling_price: Number(v.selling_price ?? 0),
    image_url: match.image_url,
    packs: choice.packs,
    note: choice.note,
    stock: v.stock ?? 0,
  };
}

async function addToCart(
  db: SupabaseClient,
  userId: string,
  m: NonNullable<ReturnType<typeof resolveLine>>,
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
    variant_name: m.variant_name,
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
  if (message.length > 500) {
    message = message.slice(0, 500);
  }

  try {
    await saveMessage(db, userId, "user", message);

    const index = await loadIndex(db);

    type RegularRow = {
      product_id: number;
      variant_id: number;
      products: { name: string } | null;
      product_variants: { name: string; price: number; selling_price: number; stock: number } | null;
    };
    const { data: regulars } = await db
      .from("regular_orders")
      .select("product_id, variant_id, products!inner(name), product_variants!inner(name, price, selling_price, stock)")
      .order("frequency_score", { ascending: false })
      .limit(5)
      .returns<RegularRow[]>();

    const regularsPrompt = (regulars ?? [])
      .map((r) => `P${r.product_id} "${r.products?.name ?? ""}" (${r.product_variants?.name ?? ""})`)
      .join("\n");

    const cart = await loadCart(db);
    const cartPrompt = cart.items
      .map((i) => `P${i.product_id} "${i.product_name}" x ${i.quantity}`)
      .join("\n");

    // 1. Primary Intelligence: Try Gemini AI
    const aiAnalysis = await geminiAnalyze(
      message,
      renderForPrompt(index),
      regularsPrompt || "No past purchases yet",
      cartPrompt || "Cart is empty",
    );

    if (aiAnalysis) {
      const type = aiAnalysis.intent_type;

      if (type === "OFF_TOPIC") {
        const reply = aiAnalysis.reply || "Didi/Bhaiya, main toh aapka Ramu Bhai hoon, ration aur kirana dukandar! Aaj ghar ke liye kya mangvana hai?";
        await saveMessage(db, userId, "bot", reply);
        return json({ success: true, reply, items: [], message_type: "text" }, 200, req);
      }

      if (type === "GREETING") {
        const reply = aiAnalysis.reply || "Namaste Didi! 🙏 Ramu Bhai hazir hai. Aaj ghar ke liye kya mangvana hai?";
        const items = (regulars ?? []).slice(0, 3).map((r) => ({
          product_id: r.product_id,
          variant_id: r.variant_id,
          name: r.products?.name ?? "",
          product_name: r.products?.name ?? "",
          variant_name: r.product_variants?.name ?? "",
          price: Number(r.product_variants?.price ?? 0),
          selling_price: Number(r.product_variants?.selling_price ?? 0),
          quantity: 1,
          image_url: "",
        }));

        await saveMessage(db, userId, "bot", reply);
        return json({
          success: true,
          reply,
          items,
          message_type: items.length > 0 ? "cartSummary" : "text",
        }, 200, req);
      }

      if (type === "SHOW_BILL") {
        if (cart.items.length === 0) {
          const reply = "Didi, abhi aapki parchi khali hai. Kuch mangvana ho toh boliye! 🛍️";
          await saveMessage(db, userId, "bot", reply);
          return json({ success: true, reply, items: [], message_type: "text" }, 200, req);
        }
        const c = await charges(db, cart.subtotal);
        const reply = aiAnalysis.reply || "Ji Didi, ye raha aapka bill/parchi. Sab sahi hai na?";
        await saveMessage(db, userId, "bot", reply);
        return json({
          success: true,
          reply,
          items: cart.items,
          message_type: "cartSummary",
          subtotal: cart.subtotal,
          final_amount: c.final,
        }, 200, req);
      }

      if (type === "CHECKOUT") {
        if (cart.items.length === 0) {
          const reply = "Didi, abhi aapki parchi khali hai. Kuch add karne ko boliye! 😊";
          await saveMessage(db, userId, "bot", reply);
          return json({ success: true, reply, items: [], message_type: "text" }, 200, req);
        }
        const c = await charges(db, cart.subtotal);
        const reply = aiAnalysis.reply || "Didi, maine checkout page khol diya hai. Apni details verify karke order place kar lijiye! 🛍️";
        await saveMessage(db, userId, "bot", reply);
        return json({
          success: true,
          reply,
          items: cart.items,
          message_type: "checkout",
          subtotal: cart.subtotal,
          final_amount: c.final,
        }, 200, req);
      }

      if (type === "BUNDLE") {
        const bundleItems: any[] = [];
        if (aiAnalysis.items && aiAnalysis.items.length > 0) {
          for (const item of aiAnalysis.items) {
            const p = index.products.find((prod) => prod.id === item.product_id);
            if (p && p.variants.length > 0) {
              const v = p.variants.find((varnt) => (varnt.stock ?? 0) > 0) ?? p.variants[0];
              bundleItems.push({
                product_id: p.id,
                product_name: p.name,
                name: p.name,
                variant_id: v.id,
                variant_name: v.name ?? "",
                price: v.price,
                selling_price: v.selling_price,
                quantity: item.quantity ?? 1,
                image_url: p.image_url,
                stock: v.stock,
              });
            }
          }
        }

        if (bundleItems.length === 0) {
          const occ = matchOccasionBundle(message);
          if (occ) {
            bundleItems.push(...resolveBundle(index, occ));
          } else {
            for (const prod of index.products.slice(0, 4)) {
              const v = prod.variants.find((varnt) => (varnt.stock ?? 0) > 0) ?? prod.variants[0];
              if (v) {
                bundleItems.push({
                  product_id: prod.id,
                  product_name: prod.name,
                  name: prod.name,
                  variant_id: v.id,
                  variant_name: v.name ?? "",
                  price: v.price,
                  selling_price: v.selling_price,
                  quantity: 1,
                  image_url: prod.image_url,
                  stock: v.stock,
                });
              }
            }
          }
        }

        const reply = aiAnalysis.reply || "Ji Didi! Aapki kit tayyar hai. Aap items check karke cart mein add kar sakti hain:";
        await saveMessage(db, userId, "bot", reply);
        return json({
          success: true,
          reply,
          items: bundleItems,
          message_type: "bundleSummary",
        }, 200, req);
      }

      if (type === "RECALL_REGULAR") {
        const added: CartLine[] = [];
        for (const r of regulars ?? []) {
          const { data: image } = await db
            .from("product_images").select("image_url").eq("product_id", r.product_id).limit(1).maybeSingle();
          added.push(
            await addToCart(db, userId, {
              product_id: r.product_id,
              product_name: r.products?.name ?? "",
              variant_id: r.variant_id,
              variant_name: r.product_variants?.name ?? "",
              price: Number(r.product_variants?.price ?? 0),
              selling_price: Number(r.product_variants?.selling_price ?? 0),
              image_url: image?.image_url ?? "",
              packs: 1,
              note: undefined,
              stock: r.product_variants?.stock ?? 0,
            }, 1),
          );
        }

        const reply = aiAnalysis.reply || (added.length > 0
          ? "Aapka regular order cart mein add kar diya gaya hai. Kuch aur chahiye?"
          : "Didi, abhi tak koi regular order nahi mila. Pehli baar kya mangvana hai?");
        await saveMessage(db, userId, "bot", reply);
        return json({ success: true, reply, items: added, message_type: "text" }, 200, req);
      }

      if (type === "ORDER" && aiAnalysis.items && aiAnalysis.items.length > 0) {
        const added: CartLine[] = [];
        for (const item of aiAnalysis.items) {
          const product = index.products.find((p) => p.id === item.product_id);
          if (!product) continue;
          const line = resolveLine({
            product_id: product.id,
            product_name: product.name,
            variants: product.variants,
            image_url: product.image_url,
          }, item.quantity ?? 1, item.unit);

          if (!line || line.stock <= 0) continue;
          const packs = Math.min(line.packs, line.stock);
          added.push(await addToCart(db, userId, line, packs));
        }

        if (added.length > 0) {
          const reply = aiAnalysis.reply || `Ji Didi, maine ${added.map((a) => a.name).join(", ")} cart me add kar diya hai!`;
          await saveMessage(db, userId, "bot", reply);
          return json({ success: true, reply, items: added, message_type: "text" }, 200, req);
        }
      }
    }

    // 2. Comprehensive Deterministic Fallback (Guarantees no failure even if LLM fails)
    if (isGreetingIntent(message)) {
      const reply = "Namaste Didi! 🙏 Ramu Bhai hazir hai. Aaj ghar ke liye kya mangvana hai?";
      await saveMessage(db, userId, "bot", reply);
      return json({ success: true, reply, items: [], message_type: "text" }, 200, req);
    }

    if (isRegularIntent(message)) {
      const added: CartLine[] = [];
      for (const r of regulars ?? []) {
        const { data: image } = await db
          .from("product_images").select("image_url").eq("product_id", r.product_id).limit(1).maybeSingle();
        added.push(
          await addToCart(db, userId, {
            product_id: r.product_id,
            product_name: r.products?.name ?? "",
            variant_id: r.variant_id,
            variant_name: r.product_variants?.name ?? "",
            price: Number(r.product_variants?.price ?? 0),
            selling_price: Number(r.product_variants?.selling_price ?? 0),
            image_url: image?.image_url ?? "",
            packs: 1,
            note: undefined,
            stock: r.product_variants?.stock ?? 0,
          }, 1),
        );
      }
      const reply = added.length > 0
        ? "Aapka regular order cart mein add kar diya gaya hai. Kuch aur chahiye?"
        : "Didi, abhi tak koi regular order nahi mila. Pehli baar kya mangvana hai?";
      await saveMessage(db, userId, "bot", reply);
      return json({ success: true, reply, items: added, message_type: "text" }, 200, req);
    }

    const occasionBundle = matchOccasionBundle(message);
    if (occasionBundle) {
      const bundleItems = resolveBundle(index, occasionBundle);
      const reply = `Ji Didi! Ye raha aapka ${occasionBundle.titles.en} (${occasionBundle.titles.hi}). Aap items check karke cart mein add kar sakti hain:`;
      await saveMessage(db, userId, "bot", reply);
      return json({ success: true, reply, items: bundleItems, message_type: "bundleSummary" }, 200, req);
    }

    if (isBillIntent(message)) {
      if (cart.items.length === 0) {
        const reply = "Didi, abhi aapki parchi khali hai. Kuch mangvana ho toh boliye! 🛍️";
        await saveMessage(db, userId, "bot", reply);
        return json({ success: true, reply, items: [], message_type: "text" }, 200, req);
      }
      const c = await charges(db, cart.subtotal);
      const reply = "Ji Didi, ye raha aapka bill/parchi. Sab sahi hai na?";
      await saveMessage(db, userId, "bot", reply);
      return json({ success: true, reply, items: cart.items, message_type: "cartSummary", subtotal: cart.subtotal, final_amount: c.final }, 200, req);
    }

    if (isConfirmIntent(message)) {
      if (cart.items.length === 0) {
        const reply = "Didi, abhi aapki parchi khali hai. Kuch add karne ko boliye! 😊";
        await saveMessage(db, userId, "bot", reply);
        return json({ success: true, reply, items: [], message_type: "text" }, 200, req);
      }
      const c = await charges(db, cart.subtotal);
      const reply = "Didi, maine checkout page khol diya hai. Apni details verify karke order place kar lijiye! 🛍️";
      await saveMessage(db, userId, "bot", reply);
      return json({ success: true, reply, items: cart.items, message_type: "checkout", subtotal: cart.subtotal, final_amount: c.final }, 200, req);
    }

    // Parse quantity + unit + product_name (e.g. "2 kg aata", "2 kilo aata", "1 litre tel", "500g sugar", "1 packet chai")
    const intents = extractIntents(message);
    const added: CartLine[] = [];

    if (intents.length > 0) {
      for (const intent of intents) {
        const resolved = matchOne(index, intent.product_name);
        if (resolved.kind === "one") {
          const line = resolveLine({
            product_id: resolved.product.id,
            product_name: resolved.product.name,
            variants: resolved.product.variants,
            image_url: resolved.product.image_url,
          }, intent.quantity, intent.unit);
          if (line && line.stock > 0) {
            added.push(await addToCart(db, userId, line, Math.min(line.packs, line.stock)));
          }
        }
      }
    }

    if (added.length === 0) {
      // Try direct product name match (e.g. "aata", "chai", "tel")
      const resolvedProduct = matchOne(index, message);
      if (resolvedProduct.kind === "one") {
        const line = resolveLine({
          product_id: resolvedProduct.product.id,
          product_name: resolvedProduct.product.name,
          variants: resolvedProduct.product.variants,
          image_url: resolvedProduct.product.image_url,
        }, 1, null);
        if (line && line.stock > 0) {
          added.push(await addToCart(db, userId, line, Math.min(line.packs, line.stock)));
        }
      }
    }

    if (added.length > 0) {
      const reply = `Ji Didi, maine ${added.map((a) => `${a.quantity}x ${a.name}`).join(", ")} cart me add kar diya hai!`;
      await saveMessage(db, userId, "bot", reply);
      return json({ success: true, reply, items: added, message_type: "text" }, 200, req);
    }

    // Ultimate polite guidance fallback
    const reply = "Ji Didi, main samajh nahi paya. Kripya product ka naam aur quantity bataiye, jaise '2 kilo aata' ya '1 packet chai'.";
    await saveMessage(db, userId, "bot", reply);
    return json({ success: true, reply, items: [], message_type: "text" }, 200, req);
  } catch (e) {
    console.error("process-chat failed:", e instanceof Error ? e.message : e);
    return json({ success: false, message: "Something went wrong" }, 500, req);
  }
});
