// Tool declarations handed to Gemini.
//
// These are composed server-side and injected into the `setup` message by the
// relay. The client never sends `setup`, so it cannot widen this list, rename a
// tool, or loosen a parameter — the relay recovers exactly the lock that
// ephemeral tokens were supposed to give us.
//
// Every tool is *executed* in Flutter against the repositories the app already
// uses, so the agent operates with precisely the permissions the signed-in user
// already has. Nothing here can reach another user's data: RLS decides that,
// and `place-order` recomputes every rupee regardless of what is said out loud.

export const TOOL_DECLARATIONS = [
  {
    name: "search_products",
    description:
      "Search the catalog by name when the full product list in your instructions is not enough. " +
      "Prefer the catalog you already have; use this only for a genuinely unfamiliar word.",
    parameters: {
      type: "OBJECT",
      properties: {
        query: { type: "STRING", description: "Hindi, Hinglish or English word to look up." },
      },
      required: ["query"],
    },
  },
  {
    name: "get_price",
    description:
      "Authoritative live price and stock for one product or variant. The catalog in your " +
      "instructions is a snapshot and may be stale; call this before quoting a price you are unsure of.",
    parameters: {
      type: "OBJECT",
      properties: {
        product_id: { type: "INTEGER", description: "Catalog product id, e.g. 3 for P3." },
        variant_id: { type: "INTEGER", description: "Optional variant id, e.g. 5 for V5." },
      },
      required: ["product_id"],
    },
  },
  {
    name: "add_to_cart",
    // Deliberately NOT declared NON_BLOCKING. That was the original plan, to keep a
    // ~150ms database write off the speech path, but in testing the model treated a
    // non-blocking cart write as optional: it announced "cart mein daal diya hai" and
    // made no tool call at all. A blocking call costs a little latency and buys the
    // guarantee that speech and cart state cannot diverge.
    description:
      "Add a quantity of one variant to the cart. This is the ONLY way anything enters the " +
      "cart; saying an item is added does not add it. Pick the variant matching the size the " +
      "customer asked for. Returns the authoritative line and the new cart total.",
    parameters: {
      type: "OBJECT",
      properties: {
        product_id: { type: "INTEGER" },
        variant_id: { type: "INTEGER", description: "Required unless the product has one variant." },
        quantity: { type: "INTEGER", description: "Whole units of this variant. Defaults to 1." },
      },
      required: ["product_id"],
    },
  },
  {
    name: "update_cart_item",
    description:
      "Set an existing cart line to an exact quantity. Use quantity 0 to remove it entirely.",
    parameters: {
      type: "OBJECT",
      properties: {
        product_id: { type: "INTEGER" },
        variant_id: { type: "INTEGER" },
        quantity: { type: "INTEGER", description: "Target quantity. 0 removes the line." },
      },
      required: ["product_id", "quantity"],
    },
  },
  {
    name: "read_cart",
    description:
      "The full cart with every line, the subtotal, and the delivery address that will be used. " +
      "You MUST call this and read the result back aloud before placing any order. " +
      "It returns a confirm_token which place_order requires.",
    parameters: { type: "OBJECT", properties: {} },
  },
  {
    name: "place_order",
    description:
      "Place the order. Only call this after read_cart, after you have read the items and the " +
      "total aloud, and after the customer has clearly agreed (for example 'haan', 'theek hai', " +
      "'kar do'). Pass the confirm_token exactly as read_cart returned it. If the customer has " +
      "not agreed, do not call this.",
    parameters: {
      type: "OBJECT",
      properties: {
        confirm_token: {
          type: "STRING",
          description: "The token returned by the most recent read_cart call.",
        },
        confirmed: {
          type: "BOOLEAN",
          description: "True only if the customer verbally agreed to place the order.",
        },
      },
      required: ["confirm_token", "confirmed"],
    },
  },
];

/** The `tools` array as the Live API `setup` message expects it. */
export const TOOLS_FOR_SETUP = [{ functionDeclarations: TOOL_DECLARATIONS }];
