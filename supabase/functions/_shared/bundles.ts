// Occasion & Event Bundle Intelligence Engine for BolKeOrder.
// Defines multi-item bundles (Ganesh Puja, Chai Nashta, Monthly Kirana)
// and resolves them dynamically against live catalog stock.

import type { CatalogIndex, Product } from "./catalog.ts";

export type BundleDefinition = {
  key: string;
  titles: { hi: string; en: string };
  keywords: string[];
  itemQueries: string[];
};

export const OCCASION_BUNDLES: BundleDefinition[] = [
  {
    key: "ganesh_puja",
    titles: { hi: "गणेश पूजा सामग्री", en: "Ganesh Puja Kit" },
    keywords: [
      "ganesh",
      "ganpati",
      "puja",
      "pooja",
      "गणेश",
      "पूजा",
      "गणपति",
    ],
    itemQueries: ["ghee", "atta", "sugar", "matchbox"],
  },
  {
    key: "chai_nashta",
    titles: { hi: "चाय नाश्ता पैकेट", en: "Chai & Snacks Pack" },
    keywords: [
      "chai",
      "nashta",
      "tea",
      "biscuit",
      "चाय",
      "नाश्ता",
      "बिस्किट",
    ],
    itemQueries: ["tea", "sugar", "biscuit", "milk"],
  },
  {
    key: "monthly_ration",
    titles: { hi: "महीने का राशन", en: "Monthly Ration Pack" },
    keywords: [
      "ration",
      "monthly",
      "rashan",
      "महीने का राशन",
      "राशन",
      "किराना",
    ],
    itemQueries: ["atta", "oil", "rice", "dal", "sugar", "salt"],
  },
];

export function matchOccasionBundle(message: string): BundleDefinition | null {
  const lower = message.toLowerCase();
  for (const bundle of OCCASION_BUNDLES) {
    if (bundle.keywords.some((kw) => lower.includes(kw.toLowerCase()))) {
      return bundle;
    }
  }
  return null;
}

export type ResolvedBundleItem = {
  product_id: number;
  product_name: string;
  variant_id: number;
  variant_name: string;
  price: number;
  selling_price: number;
  quantity: number;
  image_url: string;
  stock: number;
};

/** Resolves an occasion bundle against current catalog index, keeping only in-stock items. */
export function resolveBundle(
  index: CatalogIndex,
  bundle: BundleDefinition,
): ResolvedBundleItem[] {
  const items: ResolvedBundleItem[] = [];
  const seenProductIds = new Set<number>();

  for (const q of bundle.itemQueries) {
    const queryLower = q.toLowerCase();
    // Match catalog product by substring or alias
    const matchedProduct = index.products.find((p) => {
      if (seenProductIds.has(p.id)) return false;
      const nameMatch = p.name.toLowerCase().includes(queryLower);
      const aliasMatch = p.aliases?.some((a) => a.toLowerCase().includes(queryLower));
      return nameMatch || aliasMatch;
    });

    if (!matchedProduct) continue;

    // Pick first variant with available stock, or first variant
    const variant = matchedProduct.variants.find((v) => (v.stock ?? 0) > 0) ??
      matchedProduct.variants[0];

    if (!variant) continue;

    seenProductIds.add(matchedProduct.id);
    items.push({
      product_id: matchedProduct.id,
      product_name: matchedProduct.name,
      variant_id: variant.id,
      variant_name: variant.name ?? "",
      price: Number((variant as { price?: number | string }).price ?? 0),
      selling_price: Number(variant.selling_price ?? 0),
      quantity: 1,
      image_url: matchedProduct.image_url ?? "",
      stock: variant.stock ?? 0,
    });
  }

  return items;
}
