// Reconciling what a customer says against what the shop actually sells.
//
// This exists because the chat had no notion of it at all. The spoken unit was
// parsed and then never read, and the variant was always the cheapest pack, so
// the quantity was applied as a pack count:
//
//   "do kilo aata"     -> 2 x the 5 kg pack   = 10 kg, Rs656
//   "500 gram jeera"   -> 500 x the 100 g pack = Rs32,500
//
// Both are real outputs of the old code. The job here is to turn "two kilos"
// into "one 2 kg pack", or "four 500 g packs", or an honest refusal — never a
// silent multiplication.

/** Dimensions we can compare. Anything else is treated as a bare pack count. */
export type Dimension = "mass" | "volume" | "count";

export type Size = { dimension: Dimension; base: number };

// Everything normalises to grams / millilitres / pieces.
const UNIT_TO_BASE: Record<string, Size> = {
  kg: { dimension: "mass", base: 1000 },
  kgs: { dimension: "mass", base: 1000 },
  kilo: { dimension: "mass", base: 1000 },
  kilos: { dimension: "mass", base: 1000 },
  kilogram: { dimension: "mass", base: 1000 },
  "किलो": { dimension: "mass", base: 1000 },
  g: { dimension: "mass", base: 1 },
  gm: { dimension: "mass", base: 1 },
  gms: { dimension: "mass", base: 1 },
  gram: { dimension: "mass", base: 1 },
  grams: { dimension: "mass", base: 1 },
  "ग्राम": { dimension: "mass", base: 1 },
  l: { dimension: "volume", base: 1000 },
  ltr: { dimension: "volume", base: 1000 },
  litre: { dimension: "volume", base: 1000 },
  liter: { dimension: "volume", base: 1000 },
  "लीटर": { dimension: "volume", base: 1000 },
  ml: { dimension: "volume", base: 1 },
  "एमएल": { dimension: "volume", base: 1 },
};

/** Units that mean "one of whatever the shop sells", not a measurement. */
const PACK_WORDS = new Set([
  "packet", "packets", "pack", "packs", "piece", "pieces", "pc", "pcs",
  "dozen", "unit", "units", "बोतल", "पैकेट", "पीस", "दर्जन",
]);

export function normaliseUnit(raw: string | undefined | null): Size | null {
  if (!raw) return null;
  const u = raw.trim().toLowerCase().replace(/\.$/, "");
  if (PACK_WORDS.has(u)) return { dimension: "count", base: 1 };
  return UNIT_TO_BASE[u] ?? null;
}

/**
 * Reads a size out of a variant name.
 *
 * Variant naming in this catalog is inconsistent — "5 kg", "1 Kg", "500 g",
 * "1kg", and a bare "500" all appear — so this is deliberately forgiving. A
 * bare number is assumed to be grams, which is how the catalog uses it.
 */
export function parseVariantSize(name: string | null | undefined): Size | null {
  if (!name) return null;
  const m = name.toLowerCase().match(
    /(\d+(?:\.\d+)?)\s*(kgs?|kilos?|kilogram|किलो|gms?|grams?|g|ग्राम|ltr|litre|liter|l|लीटर|ml|एमएल)?\b/,
  );
  if (!m) return null;
  const magnitude = Number(m[1]);
  if (!Number.isFinite(magnitude) || magnitude <= 0) return null;

  if (!m[2]) return { dimension: "mass", base: magnitude };
  const unit = normaliseUnit(m[2]);
  if (!unit || unit.dimension === "count") return null;
  return { dimension: unit.dimension, base: magnitude * unit.base };
}

export type VariantLike = {
  id: number;
  name: string | null;
  selling_price: number | string | null;
  stock: number | null;
};

export type Choice = {
  variant: VariantLike;
  packs: number;
  /** Set when we could not honour the request exactly. */
  note?: string;
};

/** Never let one line run away, whatever was said or misheard. */
export const MAX_PACKS = 20;

/**
 * Picks the variant and pack count for a spoken quantity.
 *
 * Order of preference:
 *   1. a single pack that IS the requested amount   ("do kilo" -> one 2 kg pack)
 *   2. whole packs of a matching unit, fewest packs ("do kilo" -> four 500 g)
 *   3. nearest whole number of packs, flagged so the reply can say so
 *   4. no compatible unit -> treat the number as a pack count
 *
 * In-stock variants always beat out-of-stock ones, because offering something
 * that cannot be reserved just moves the failure to checkout.
 */
export function chooseVariant(
  variants: VariantLike[],
  quantity: number,
  spokenUnit?: string | null,
): Choice | null {
  const usable = variants.filter((v) => v && v.id != null);
  if (usable.length === 0) return null;

  const inStock = usable.filter((v) => (v.stock ?? 0) > 0);
  const pool = inStock.length > 0 ? inStock : usable;

  const cheapest = [...pool].sort(
    (a, b) => Number(a.selling_price ?? 0) - Number(b.selling_price ?? 0),
  );

  const spoken = normaliseUnit(spokenUnit);

  // No unit, or a pack word: the number is simply how many packs they want.
  if (!spoken || spoken.dimension === "count") {
    return {
      variant: cheapest[0],
      packs: clampPacks(Math.max(1, Math.round(quantity))),
    };
  }

  const wantBase = quantity * spoken.base;
  if (!Number.isFinite(wantBase) || wantBase <= 0) return null;

  type Scored = { v: VariantLike; packs: number; exact: boolean; err: number };
  const scored: Scored[] = [];

  for (const v of pool) {
    const size = parseVariantSize(v.name);
    if (!size || size.dimension !== spoken.dimension) continue;

    const raw = wantBase / size.base;
    const packs = Math.max(1, Math.round(raw));
    // Relative error after rounding to whole packs.
    const err = Math.abs(packs * size.base - wantBase) / wantBase;
    scored.push({ v, packs, exact: err < 0.001, err });
  }

  if (scored.length === 0) {
    // Nothing sold by that unit. Fall back to a pack count rather than
    // multiplying a weight by a pack price.
    return {
      variant: cheapest[0],
      packs: clampPacks(Math.max(1, Math.round(quantity))),
      note: "unit_unknown",
    };
  }

  scored.sort((a, b) => {
    // Exact first, then closest, then fewest packs, then cheapest.
    if (a.exact !== b.exact) return a.exact ? -1 : 1;
    if (Math.abs(a.err - b.err) > 0.001) return a.err - b.err;
    if (a.packs !== b.packs) return a.packs - b.packs;
    return Number(a.v.selling_price ?? 0) - Number(b.v.selling_price ?? 0);
  });

  const best = scored[0];
  return {
    variant: best.v,
    packs: clampPacks(best.packs),
    // Worth telling the customer when we rounded by more than a tenth: "adha
    // kilo" against a 5 kg-only product is not something to do silently.
    note: best.exact ? undefined : best.err > 0.1 ? "rounded" : undefined,
  };
}

function clampPacks(n: number): number {
  if (!Number.isFinite(n) || n < 1) return 1;
  return Math.min(MAX_PACKS, Math.floor(n));
}

/** Escapes a value going into a PostgREST `ilike` / `.or()` filter. */
export function escapeFilterValue(raw: string): string {
  // `%` and `_` are ilike wildcards; comma, parens and dots terminate or
  // restructure a PostgREST filter expression. The Gemini path can put
  // attacker-influenced text here, so this is a real boundary, not hygiene.
  return raw.replace(/[%_,()\\.]/g, " ").replace(/\s+/g, " ").trim();
}
