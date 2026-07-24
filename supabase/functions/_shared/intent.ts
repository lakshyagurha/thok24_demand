// Deterministic intent extraction for BolKeOrder.
//
// This is the cheap path. It runs FIRST, and Gemini is only called when it comes back
// empty -- which is the architecture the project brief describes, though the PHP version
// did the opposite (it always called Gemini and only fell back to regex when the API key
// was missing). Every utterance handled here is an LLM call not made.
//
// Two deliberate widenings over the PHP regexes, both aimed at the Hindi-first user:
//   1. The PHP patterns matched product names as [a-zA-Z\s] only, so a spoken Devanagari
//      name never matched and always cost a Gemini call. Devanagari is included here.
//   2. The PHP used preg_match (first match only), so "2 kilo aata aur 1 kilo chawal"
//      extracted one item. This matches repeatedly and splits on conjunctions.

export type Intent = { product_name: string; quantity: number; unit: string };

const UNITS = [
  "kilo",
  "kg",
  "packet",
  "pack",
  "liter",
  "litre",
  "ml",
  "g",
  "gm",
  "gram",
  "pc",
  "piece",
  "dozen",
  "bottle",
  // Devanagari
  "किलो",
  "ग्राम",
  "लीटर",
  "पैकेट",
  "पीस",
  "दर्जन",
];

// Spoken numerals. Hindi-first users say "do kilo", not "2 kilo".
const NUMBER_WORDS: Record<string, number> = {
  ek: 1,
  do: 2,
  teen: 3,
  tin: 3,
  char: 4,
  chaar: 4,
  paanch: 5,
  panch: 5,
  chah: 6,
  chhah: 6,
  che: 6,
  saat: 7,
  aath: 8,
  nau: 9,
  das: 10,
  dus: 10,
  adha: 0.5,
  aadha: 0.5,
  dhai: 2.5,
  derh: 1.5,
  "एक": 1,
  "दो": 2,
  "तीन": 3,
  "चार": 4,
  "पांच": 5,
  "पाँच": 5,
  "छह": 6,
  "सात": 7,
  "आठ": 8,
  "नौ": 9,
  "दस": 10,
  "आधा": 0.5,
};

const UNIT_RE = UNITS.join("|");
// Product-name character class: Latin letters, Devanagari block, and spaces.
const NAME_CHARS = "a-zA-Z\\u0900-\\u097F";
const QTY = `(\\d+(?:\\.\\d+)?|${Object.keys(NUMBER_WORDS).join("|")})`;

// "2 kilo aata" / "do किलो आटा"
const QTY_UNIT_NAME = new RegExp(
  `${QTY}\\s*(${UNIT_RE})s?\\s+([${NAME_CHARS}][${NAME_CHARS}\\s]*)`,
  "gi",
);
// "aata 2 kilo" / "आटा दो किलो"
const NAME_QTY_UNIT = new RegExp(
  `([${NAME_CHARS}][${NAME_CHARS}\\s]*?)\\s*${QTY}\\s*(${UNIT_RE})s?`,
  "gi",
);
// "2 aata" -- quantity with no unit at all, very common in speech.
const QTY_NAME = new RegExp(
  `${QTY}\\s+([${NAME_CHARS}][${NAME_CHARS}\\s]*)`,
  "gi",
);

/** Words that are never a product name -- filler, verbs, politeness. */
const STOPWORDS = new Set([
  "bhej",
  "bhejo",
  "bhej do",
  "do",
  "de",
  "dedo",
  "chahiye",
  "mangwa",
  "mangvana",
  "add",
  "kar",
  "karo",
  "please",
  "aur",
  "और",
  "भेज",
  "दो",
  "चाहिए",
  "और भी",
  "ka",
  "ki",
  "ke",
  "mein",
  "me",
  "hai",
  "ho",
  "kuch",
]);

function toQuantity(raw: string): number {
  const n = Number(raw);
  if (!Number.isNaN(n)) return n;
  return NUMBER_WORDS[raw.toLowerCase()] ?? 1;
}

const UNIT_SET = new Set(UNITS);

function cleanName(raw: string): string {
  // Unit words are dropped wherever they appear, not just when the whole candidate is a
  // unit. Overlapping patterns otherwise capture things like "kilo aata" out of
  // "2 kilo aata aur 1 kilo chawal", which then looks like a third distinct product.
  const words = raw
    .trim()
    .toLowerCase()
    .split(/\s+/)
    .filter((w) =>
      w && !STOPWORDS.has(w) && !UNIT_SET.has(w) && !(w in NUMBER_WORDS)
    );
  return words.join(" ").trim();
}

/**
 * Returns every order intent found in the message. Empty array means "not confidently
 * understood" -- the caller should then fall back to the LLM.
 */
export function extractIntents(message: string): Intent[] {
  const found: Intent[] = [];
  const seen = new Set<string>();

  const push = (name: string, qty: number, unit: string) => {
    const cleaned = cleanName(name);
    // A bare unit or a one-character fragment is noise, not a product.
    if (cleaned.length < 2) return;
    if (UNITS.includes(cleaned)) return;
    const key = cleaned;
    if (seen.has(key)) return;
    seen.add(key);
    found.push({
      product_name: cleaned,
      quantity: qty,
      unit: unit.toLowerCase(),
    });
  };

  for (const m of message.matchAll(QTY_UNIT_NAME)) {
    push(m[3], toQuantity(m[1]), m[2]);
  }
  for (const m of message.matchAll(NAME_QTY_UNIT)) {
    push(m[1], toQuantity(m[2]), m[3]);
  }
  // Only try the unit-less pattern if the stronger patterns found nothing, otherwise it
  // re-matches fragments of what they already captured.
  if (found.length === 0) {
    for (const m of message.matchAll(QTY_NAME)) {
      push(m[2], toQuantity(m[1]), "");
    }
  }

  return found;
}

// --- Conversational intents (ported verbatim from process_chat.php) ---------

/** "bill dikhao", "parchi", "hisaab" -> show the running bill. */
export function isBillIntent(msg: string): boolean {
  return /\b(bill|parchi|summary|hisab|hisaab|dikh|show)\b/i.test(msg) ||
    /(पर्ची|बिल|हिसाब|दिखा)/.test(msg);
}

/** "confirm", "book", "pakka" -> proceed to checkout. */
export function isConfirmIntent(msg: string): boolean {
  return /\b(confirm|book|pakka|pikka|chahiye)\b/i.test(msg) ||
    /(पक्का|कन्फर्म|बुक)/.test(msg);
}

/** "regular", "wahi", "pichla" -> re-order the usual. */
export function isRegularIntent(msg: string): boolean {
  return /(regular|wahi|pichla|hamesha)/i.test(msg) ||
    /(वही|पिछला|हमेशा|रोज)/.test(msg);
}
