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
// Null-prototype: `w in NUMBER_WORDS` (see toQuantity) would otherwise answer
// true for "constructor", "toString" and friends, and the `?? 1` fallback would
// hand back a *function* as a quantity.
const NUMBER_WORDS: Record<string, number> = Object.assign(
  Object.create(null) as Record<string, number>,
  {
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
  // Fractions. These are how people actually buy dal and masala, and every one
  // of them was missing: "paav bhar haldi" is a quarter kilo, not one packet.
  adha: 0.5,
  aadha: 0.5,
  aadhaa: 0.5,
  paav: 0.25,
  pav: 0.25,
  pao: 0.25,
  sawa: 1.25,
  sava: 1.25,
  paune: 0.75,
  pauna: 0.75,
  dhai: 2.5,
  dhaai: 2.5,
  adhai: 2.5,
  derh: 1.5,
  dedh: 1.5, // the commoner spelling; only `derh` existed
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
  "पाव": 0.25,
  "सवा": 1.25,
  "पौने": 0.75,
  "डेढ़": 1.5,
  "डेढ": 1.5,
  "ढाई": 2.5,
  },
);

const UNIT_RE = UNITS.join("|");
// Product-name character class: Latin letters, Devanagari block, and spaces.
const NAME_CHARS = "a-zA-Z\\u0900-\\u097F";
// Longest-first, so "sawa" is not shadowed by a shorter key that prefixes it,
// and Devanagari digits are accepted alongside ASCII.
const NUMBER_WORD_KEYS = Object.keys(NUMBER_WORDS).sort(
  (a, b) => b.length - a.length,
);
const QTY = `([\\d०-९]+(?:[.,][\\d०-९]+)?|${NUMBER_WORD_KEYS.join("|")})`;

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
  // Conversational nouns. Without these, "ek bill dikhao" parses as a request
  // for one unit of a product called "bill".
  "bill",
  "parchi",
  "hisab",
  "hisaab",
  "summary",
  "cart",
  "order",
  "confirm",
  "पर्ची",
  "बिल",
  "हिसाब",
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

/** Devanagari digits ०-९ to ASCII, so "२ किलो" parses like "2 kilo". */
function westernise(raw: string): string {
  return raw.replace(
    /[०-९]/g,
    (d) => String(d.charCodeAt(0) - 0x0966),
  );
}

function toQuantity(raw: string): number {
  // `\d` is ASCII-only, so a Devanagari numeral never reached Number(). The
  // existing test suite hid this by rewriting २ to 2 before asserting.
  const n = Number(westernise(raw));
  if (!Number.isNaN(n)) return n;
  const word = NUMBER_WORDS[raw.toLowerCase()];
  return typeof word === "number" ? word : 1;
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

/** "bill dikhao", "parchi", "hisaab" -> show the running bill.
 *
 * `\bdikh\b` never matched "dikhao" — the word boundary fails on the trailing
 * "ao" — so this only ever fired on the word "bill" being present anywhere.
 * Widened to the real word forms, and the caller must still run extraction
 * first so "parchi mein 2 kilo aata daal do" adds atta rather than showing a
 * bill.
 */
export function isBillIntent(msg: string): boolean {
  return /\b(bill|parchi|summary|hisab|hisaab)\b/i.test(msg) ||
    /\bdikh(a|ao|aiye|aye)?\b/i.test(msg) ||
    /(पर्ची|बिल|हिसाब|दिखा)/.test(msg);
}

/** "confirm", "book", "pakka" -> proceed to checkout.
 *
 * `chahiye` is deliberately NOT here. It is the commonest ordering verb in the
 * language ("do kilo aata chahiye") and it is already listed as filler in
 * STOPWORDS, so treating it as a confirmation checked out an unchanged cart
 * instead of adding the atta. It is a request, not an agreement.
 *
 * Callers must run product extraction FIRST and only consult this when nothing
 * was extracted — otherwise "parchi mein 2 kilo aata daal do" is read as a
 * request for the bill and silently adds nothing.
 */
export function isConfirmIntent(msg: string): boolean {
  return /\b(confirm|book|pakka|pikka|order kar|place)\b/i.test(msg) ||
    /(पक्का|कन्फर्म|बुक|ऑर्डर कर)/.test(msg);
}

/** "regular", "wahi", "pichla" -> re-order the usual. */
export function isRegularIntent(msg: string): boolean {
  return /(regular|wahi|pichla|hamesha)/i.test(msg) ||
    /(वही|पिछला|हमेशा|रोज)/.test(msg);
}
