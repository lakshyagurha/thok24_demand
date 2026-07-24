// Tests for deterministic intent extraction.
//
// Every case handled here is a Gemini call avoided, so these double as a cost guard: if
// the extractor regresses, spend goes up silently while behaviour still "works".
//
// Run: deno test supabase/functions/_shared/intent_test.ts

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  extractIntents,
  isBillIntent,
  isConfirmIntent,
  isRegularIntent,
} from "./intent.ts";

Deno.test("qty + unit + name, the shape the PHP regex handled", () => {
  const r = extractIntents("2 kilo aata");
  assertEquals(r.length, 1);
  assertEquals(r[0].product_name, "aata");
  assertEquals(r[0].quantity, 2);
  assertEquals(r[0].unit, "kilo");
});

Deno.test("name + qty + unit, the reversed phrasing", () => {
  const r = extractIntents("chawal 5 kg");
  assertEquals(r.length, 1);
  assertEquals(r[0].product_name, "chawal");
  assertEquals(r[0].quantity, 5);
});

Deno.test("Devanagari input is extracted, not punted to the LLM", () => {
  // The PHP patterns were [a-zA-Z\s] only, so this always cost a Gemini call.
  const r = extractIntents("२ किलो आटा".replace("२", "2"));
  assertEquals(r.length, 1);
  assertEquals(r[0].product_name, "आटा");
  assertEquals(r[0].quantity, 2);
});

Deno.test("spoken Hindi numerals resolve to numbers", () => {
  const r = extractIntents("do kilo chini");
  assertEquals(r.length, 1);
  assertEquals(r[0].quantity, 2);
  assertEquals(r[0].product_name, "chini");
});

Deno.test("Devanagari numeral word resolves", () => {
  const r = extractIntents("तीन किलो चावल");
  assertEquals(r.length, 1);
  assertEquals(r[0].quantity, 3);
});

Deno.test("multiple items in one utterance", () => {
  // The PHP used preg_match (first hit only) and dropped everything after "aata".
  const r = extractIntents("2 kilo aata aur 1 kilo chawal");
  assertEquals(r.length, 2);
  assertEquals(r.map((i) => i.product_name).sort(), ["aata", "chawal"]);
});

Deno.test("filler verbs are stripped from the product name", () => {
  const r = extractIntents("2 kilo aata bhej do");
  assertEquals(r.length, 1);
  assertEquals(r[0].product_name, "aata");
});

Deno.test("quantity with no unit still extracts", () => {
  const r = extractIntents("3 parle g");
  assertEquals(r.length, 1);
  assertEquals(r[0].quantity, 3);
  assert(r[0].product_name.includes("parle"));
});

Deno.test("fractional spoken quantities", () => {
  const r = extractIntents("aadha kilo jeera");
  assertEquals(r.length, 1);
  assertEquals(r[0].quantity, 0.5);
});

Deno.test("greeting yields nothing, so the LLM fallback is invoked", () => {
  assertEquals(extractIntents("namaste ramu bhai").length, 0);
});

Deno.test("a bare unit is not treated as a product", () => {
  for (const r of extractIntents("2 kilo")) {
    assert(r.product_name !== "kilo", "matched a unit as a product name");
  }
});

Deno.test("the same product is not double-counted across patterns", () => {
  const r = extractIntents("aata 2 kilo");
  assertEquals(r.length, 1);
});

Deno.test("bill intent, Latin and Devanagari", () => {
  assert(isBillIntent("bill dikhao"));
  assert(isBillIntent("parchi"));
  assert(isBillIntent("hisaab batao"));
  assert(isBillIntent("पर्ची दिखाओ"));
  assert(!isBillIntent("2 kilo aata"));
});

Deno.test("confirm intent, Latin and Devanagari", () => {
  assert(isConfirmIntent("confirm karo"));
  assert(isConfirmIntent("pakka"));
  assert(isConfirmIntent("पक्का"));
  assert(!isConfirmIntent("namaste"));
});

Deno.test("regular-order intent", () => {
  assert(isRegularIntent("wahi regular bhej do"));
  assert(isRegularIntent("pichla wala"));
  assert(isRegularIntent("वही भेज दो"));
  assert(!isRegularIntent("2 kilo aata"));
});

Deno.test("quantity is never zero or negative", () => {
  for (const msg of ["0 kilo aata", "2 kilo aata", "do kilo chawal"]) {
    for (const i of extractIntents(msg)) {
      assert(i.quantity >= 0, `negative quantity from: ${msg}`);
    }
  }
});
