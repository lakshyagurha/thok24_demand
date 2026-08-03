// Regression tests for the defects that put wrong money in real carts.
//
// Every case below is a real output of the previous code, taken from an audit
// of process-chat. The old path parsed the spoken unit, threw it away, picked
// the cheapest variant, and applied the quantity as a pack count.
//
// Run: deno test supabase/functions/_shared/units_test.ts

import { assertEquals } from "jsr:@std/assert@1";
import {
  chooseVariant,
  escapeFilterValue,
  MAX_PACKS,
  parseVariantSize,
} from "./units.ts";

// Real rows from the live catalog.
const ATTA = [
  { id: 3, name: "5 kg", selling_price: 328, stock: 99 },
  { id: 2, name: "10 kg", selling_price: 474, stock: 87 },
];
const MOONG = [
  { id: 4, name: "500 g", selling_price: 67, stock: 96 },
  { id: 5, name: "1 kg", selling_price: 100, stock: 99 },
];
const RICE = [
  { id: 1, name: "500 g", selling_price: 30, stock: 94 },
  { id: 46, name: "1 Kg", selling_price: 50, stock: 100 },
  { id: 47, name: "2 Kg", selling_price: 80, stock: 100 },
];
const JEERA = [{ id: 22, name: "100 g", selling_price: 65, stock: 50 }];

const total = (c: NonNullable<ReturnType<typeof chooseVariant>>) =>
  Number(c.variant.selling_price) * c.packs;

Deno.test("500 gram jeera does not become 500 packets (was Rs32,500)", () => {
  const c = chooseVariant(JEERA, 500, "gram")!;
  assertEquals(c.packs, 5); // 500g / 100g
  assertEquals(total(c), 325);
});

Deno.test("do kilo aata does not become 10 kg (was Rs656)", () => {
  const c = chooseVariant(ATTA, 2, "kilo")!;
  // No 2 kg atta exists, so one 5 kg pack is the closest single purchase —
  // and it is flagged so the reply can say so rather than silently overshoot.
  assertEquals(c.variant.id, 3);
  assertEquals(c.packs, 1);
  assertEquals(c.note, "rounded");
});

Deno.test("an exact pack is preferred over multiples of a smaller one", () => {
  const c = chooseVariant(RICE, 2, "kilo")!;
  assertEquals(c.variant.name, "2 Kg"); // not 4 x 500g, not 2 x 1Kg
  assertEquals(c.packs, 1);
  assertEquals(c.note, undefined);
});

Deno.test("adha kilo picks the 500g pack exactly", () => {
  const c = chooseVariant(MOONG, 0.5, "kilo")!;
  assertEquals(c.variant.name, "500 g");
  assertEquals(c.packs, 1);
  assertEquals(c.note, undefined);
});

Deno.test("ek kilo prefers the 1kg pack over two 500g", () => {
  const c = chooseVariant(MOONG, 1, "kilo")!;
  assertEquals(c.variant.name, "1 kg");
  assertEquals(c.packs, 1);
});

Deno.test("no unit means pack count, not weight", () => {
  const c = chooseVariant(ATTA, 2, null)!;
  assertEquals(c.packs, 2);
  assertEquals(c.variant.id, 3); // cheapest, as before
});

Deno.test("quantity is capped so a mishearing cannot run away", () => {
  const c = chooseVariant(JEERA, 100000, "gram")!;
  assertEquals(c.packs, MAX_PACKS);
});

Deno.test("out-of-stock variants are not offered when a stocked one exists", () => {
  const mixed = [
    { id: 1, name: "500 g", selling_price: 30, stock: 0 },
    { id: 2, name: "1 kg", selling_price: 50, stock: 10 },
  ];
  const c = chooseVariant(mixed, 500, "gram")!;
  assertEquals(c.variant.id, 2); // never the dead one
});

Deno.test("variant sizes parse across the catalog's inconsistent naming", () => {
  assertEquals(parseVariantSize("5 kg"), { dimension: "mass", base: 5000 });
  assertEquals(parseVariantSize("1 Kg"), { dimension: "mass", base: 1000 });
  assertEquals(parseVariantSize("500 g"), { dimension: "mass", base: 500 });
  assertEquals(parseVariantSize("1kg"), { dimension: "mass", base: 1000 });
  // A bare number is grams, which is how this catalog uses it.
  assertEquals(parseVariantSize("500"), { dimension: "mass", base: 500 });
  assertEquals(parseVariantSize("1 ltr"), { dimension: "volume", base: 1000 });
});

Deno.test("mismatched dimensions fall back to a pack count, not a wrong weight", () => {
  // Asking for litres of something sold by weight must not multiply.
  const c = chooseVariant(ATTA, 2, "litre")!;
  assertEquals(c.packs, 2);
  assertEquals(c.note, "unit_unknown");
});

Deno.test("filter values are escaped for PostgREST", () => {
  // `%`/`_` are ilike wildcards; commas and parens restructure a .or() filter.
  // The Gemini fallback can put attacker-influenced text here.
  assertEquals(escapeFilterValue("aa%ta"), "aa ta");
  assertEquals(escapeFilterValue("a,b)c"), "a b c");
  assertEquals(escapeFilterValue("name.ilike.x"), "name ilike x");
});
