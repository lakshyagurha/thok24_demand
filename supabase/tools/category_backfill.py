#!/usr/bin/env python3
"""
Remaps every product onto the new category tree, and proves the remap before it happens.

WHY THIS EXISTS
---------------
The 12 flat categories are being replaced by 6 umbrellas over 34 shelves
(20260731000002_category_tree_seed.sql). The 37 products currently sit in 4 of the old
12, several of them in the wrong one -- `Taj Mahal Deccan Rose Tea` is filed under
"Breakfast & Sauces" while an empty "Tea, Coffee & More" sits one tile away.

Moving them is a one-line UPDATE per product. Getting it *wrong* is a catalog where
shoppers cannot find tea. So the mapping below is explicit, one line per SKU, reviewed
by a human against the product names, and this tool exists to print exactly what would
change before anything is written.

THE MAPPING IS THE SOURCE OF TRUTH. `20260731000003_category_backfill_products.sql` is
generated from it with --emit-sql; if you edit one, regenerate the other. --dry-run
checks they agree.

USAGE
-----
Dry run -- reads only, needs no secret, safe anytime. This is the default:

    python3 supabase/tools/category_backfill.py

    Prints the full old -> new diff per product plus a before/after count per shelf,
    and exits non-zero if any rule is broken.

Regenerate the migration from the mapping below:

    python3 supabase/tools/category_backfill.py --emit-sql

Verify AFTER the migration has been applied:

    python3 supabase/tools/category_backfill.py --verify

This tool never writes to the database. The write path is the migration, applied through
the normal migration flow, so the change is reviewable as a diff and has a rollback.

Reads use the publishable (anon) key from Frontend/dx_mart/env/dev.json -- the same
read-only access any app user has. Override with SUPABASE_URL / SUPABASE_ANON_KEY.
"""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ENV_FILE = REPO / "Frontend" / "dx_mart" / "env" / "dev.json"
MIGRATION = REPO / "supabase" / "migrations" / "20260731000003_category_backfill_products.sql"

# ---------------------------------------------------------------------------
# The mapping. One line per SKU, product id -> destination slug.
# ---------------------------------------------------------------------------
#
# Four of these were judgement calls and are marked JUDGEMENT. They are listed in
# docs/category-system-plan.md §3.5 so they can be overruled without re-reading this file.

PRODUCT_MAP = {
    # --- from 23 "Atta, Rice, Oil & Dals" -----------------------------------
    1:  ("atta-rice-dal",       "Bhagyalakshmi Rice Flour"),
    2:  ("atta-rice-dal",       "Fortune Chakki Fresh Atta"),
    3:  ("atta-rice-dal",       "Tata Sampann Unpolished Green Moong"),
    # JUDGEMENT: raw groundnut is a nuts-and-seeds SKU, but a kirana shopper may look
    # for it beside the dals. Move to atta-rice-dal if that reads better on the shelf.
    4:  ("dry-fruits-seeds",    "Sri Bhagyalakshmi Ground Nut"),
    5:  ("atta-rice-dal",       "Fortune Suji"),
    6:  ("oil-ghee-masala",     "Akshayakalpa Organic Desi Cow Ghee"),
    7:  ("atta-rice-dal",       "Aashirvaad Superior MP Atta"),
    8:  ("oil-ghee-masala",     "Fortune Kachi Ghani Mustard Oil"),
    9:  ("atta-rice-dal",       "Fortune Sona Masoori Supreme Raw Aged Rice"),
    10: ("atta-rice-dal",       "Fortune Unpolished Kabuli Chana"),

    # --- from 24 "Breakfast & Sauces" ---------------------------------------
    11: ("sauces-spreads",      "9am Tomato Ketchup"),
    12: ("sauces-spreads",      "Kissan Fresh Tomato Ketchup"),
    13: ("breakfast-cereal",    "Kellogg's Chocos"),
    14: ("sauces-spreads",      "MyFitness Original Peanut Butter"),
    15: ("sauces-spreads",      "Hellmann's Eggless Mayonnaise"),
    # JUDGEMENT: honey sells as a spread more than as a supplement, which is also where
    # Blinkit files it. Alternative home is health-nutrition.
    16: ("sauces-spreads",      "Akshayakalpa Wild Honey"),
    17: ("dry-fruits-seeds",    "Popular Fit Eats Chia Seeds"),
    18: ("breakfast-cereal",    "Slurrp Farm Fruit Cereal Trial Pack"),
    # The clearest miscategorisation in the catalog: tea filed under Breakfast & Sauces.
    19: ("tea-coffee-drinks",   "Taj Mahal Deccan Rose Tea"),
    20: ("sauces-spreads",      "Dabur Honey Squeezy"),          # JUDGEMENT, as id 16
    21: ("breakfast-cereal",    "Kellogg's Muesli Fruit Nut & Seeds"),
    22: ("dry-fruits-seeds",    "Khari Foods Kalmi Dates / Khajur"),

    # --- from 25 "Dairy, Bread & Eggs" --------------------------------------
    23: ("dairy-bread-eggs",    "Amul Taaza Homogenised Toned Milk"),
    # JUDGEMENT: dairy whitener is bought for chai, so tea-coffee-drinks is arguable.
    # Filed with dairy, following Blinkit.
    25: ("dairy-bread-eggs",    "Nestle EveryDay Dairy Whitener"),
    26: ("dairy-bread-eggs",    "Britannia 100% Whole Wheat Bread"),
    27: ("dairy-bread-eggs",    "Amul Salted Butter"),
    28: ("dairy-bread-eggs",    "Amul Fresh Malai Paneer"),
    29: ("dairy-bread-eggs",    "Amul Masti Dahi Cup"),
    30: ("biscuits-bakery",     "Cake Tale Muffin Vanilla Chocochip"),
    31: ("biscuits-bakery",     "Theobroma Christmas Plum Cake"),
    32: ("dairy-bread-eggs",    "Vijay White Eggs"),
    33: ("dairy-bread-eggs",    "Amul Fresh Cream"),

    # --- from 26 "Electronics & Appliances" ---------------------------------
    24: ("bulbs-batteries",     "Philips 9 W LED Bulb Cool White"),
    34: ("kitchen-appliances",  "Havells Insta Cook QT 1200 W Induction Cooktop"),
    35: ("kitchen-appliances",  "Bajaj GX-1 Mixer Grinder 500W"),
}

# Withdrawn, not deleted: DxMart is a grocery/daily-essentials shop and these two are
# consumer gadgets. `products.is_active = false` keeps their variants, images and
# hand-built Hindi voice aliases intact, so reactivating is a one-column update.
RETIRE_PRODUCTS = {
    36: "Noise ColorFit Icon 2 Vista Smartwatch",
    37: "Mivi Roam2 Bluetooth Speaker",
}

# Banner 8 targets old category 30 ("Masala & Dry Fruits"), which becomes
# "Dry Fruits & Seeds". The FK survives the rename, so this is a note for whoever
# reviews the creative, not a data change.
BANNER_NOTES = {8: "was Masala & Dry Fruits, now Dry Fruits & Seeds -- check the artwork"}

# Shelves that must exist for the mapping to resolve.
EXPECTED_SLUGS = sorted({slug for slug, _ in PRODUCT_MAP.values()})

UNCATEGORISED_CEILING = 0.02  # plan rule: >2% of active SKUs means the tree is wrong


# ---------------------------------------------------------------------------
# Reading
# ---------------------------------------------------------------------------

def credentials():
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_ANON_KEY")
    if url and key:
        return url.rstrip("/"), key
    if not ENV_FILE.exists():
        sys.exit(f"no credentials: set SUPABASE_URL and SUPABASE_ANON_KEY, or create {ENV_FILE}")
    env = json.loads(ENV_FILE.read_text())
    return env["SUPABASE_URL"].rstrip("/"), env["SUPABASE_PUBLISHABLE_KEY"]


class MissingColumn(Exception):
    """PostgREST 42703 -- the tree columns are not applied yet."""


def get(url, key, path):
    req = urllib.request.Request(
        f"{url}/rest/v1/{path}",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        if '"42703"' in body:
            raise MissingColumn(body[:200])
        sys.exit(f"read failed on {path}: {e.code} {body[:300]}")


def load(url, key):
    """Reads live state, tolerating a database where ...01 has not been applied yet.

    The dry run has to be useful *before* the schema lands -- reviewing the mapping is
    the whole point of running it first -- so a missing column degrades to defaults
    rather than aborting.
    """
    tree_cols = "id,name,slug,parent_id,level,sort_order,is_active"
    try:
        cats = get(url, key, f"main_category?select={tree_cols}&order=id")
        schema_applied = True
    except MissingColumn:
        cats = get(url, key, "main_category?select=id,name&order=id")
        for c in cats:
            c.update(slug=None, parent_id=None, level=2, sort_order=0, is_active=True)
        schema_applied = False

    cols = "id,name,main_category_id"
    try:
        prods = get(url, key, f"products?select={cols},is_active&order=id&limit=2000")
    except MissingColumn:
        prods = get(url, key, f"products?select={cols}&order=id&limit=2000")
        for p in prods:
            p["is_active"] = True
    return cats, prods, schema_applied


# ---------------------------------------------------------------------------
# Checking
# ---------------------------------------------------------------------------

def check(cats, prods, schema_applied):
    """Returns (problems, warnings). Non-empty problems => exit non-zero."""
    problems, warnings = [], []
    by_slug = {c["slug"]: c for c in cats if c.get("slug")}
    by_id = {c["id"]: c for c in cats}

    if schema_applied:
        # Every destination must exist, be level >= 2, and be a leaf.
        has_children = {c["parent_id"] for c in cats if c.get("parent_id")}
        for slug in EXPECTED_SLUGS:
            c = by_slug.get(slug)
            if c is None:
                problems.append(f"destination shelf '{slug}' does not exist")
                continue
            if c["level"] < 2:
                problems.append(f"'{slug}' is level {c['level']}; products need level >= 2")
            if c["id"] in has_children:
                problems.append(f"'{slug}' has child categories; products should sit on a leaf")
            if not c["is_active"]:
                warnings.append(f"'{slug}' is inactive -- its products will not be browsable")
    else:
        warnings.append(
            "the tree is not applied yet (main_category has no slug column), so this run "
            "is a MAPPING PREVIEW: destinations are shown by slug and cannot be validated "
            "against the database. Apply 20260731000001 and ...02, then re-run.")

    # Every product must be accounted for exactly once.
    live_ids = {p["id"] for p in prods}
    mapped = set(PRODUCT_MAP) | set(RETIRE_PRODUCTS)
    for pid in sorted(live_ids - mapped):
        name = next(p["name"] for p in prods if p["id"] == pid)
        problems.append(f"product {pid} '{name[:50]}' is not in the mapping")
    for pid in sorted(mapped - live_ids):
        problems.append(f"mapping references product {pid}, which does not exist")
    both = set(PRODUCT_MAP) & set(RETIRE_PRODUCTS)
    if both:
        problems.append(f"products in both the map and the retire list: {sorted(both)}")

    # The "Others is not a dumping ground" rule.
    unc = by_slug.get("uncategorised")
    if unc:
        n_unc = sum(1 for s, _ in PRODUCT_MAP.values() if s == "uncategorised")
        n_active = len(PRODUCT_MAP)
        if n_active and n_unc / n_active > UNCATEGORISED_CEILING:
            problems.append(
                f"Uncategorised holds {n_unc}/{n_active} SKUs "
                f"({n_unc / n_active:.1%} > {UNCATEGORISED_CEILING:.0%}) -- the tree is wrong")

    if not schema_applied:
        return problems, warnings

    # Naming rules on every active category.
    for c in cats:
        if not c["is_active"]:
            continue
        n = c["name"] or ""
        if len(n) > 22:
            problems.append(f"category '{n}' is {len(n)} chars (max 22)")
        if n.count("&") > 1:
            problems.append(f"category '{n}' uses more than one '&'")
        if not c.get("slug"):
            problems.append(f"category '{n}' has no slug")

    # Sibling ordering must be unambiguous.
    seen = defaultdict(Counter)
    for c in cats:
        if c["is_active"]:
            seen[c["parent_id"]][c["sort_order"]] += 1
    for parent, orders in seen.items():
        dupes = [o for o, n in orders.items() if n > 1]
        if dupes:
            pname = by_id.get(parent, {}).get("name", "<root>")
            problems.append(f"siblings under '{pname}' share sort_order {dupes}")

    # Shelves that end up empty are expected (24 of them) but worth reporting.
    landing = Counter(slug for slug, _ in PRODUCT_MAP.values())
    empty = [c["name"] for c in cats
             if c["is_active"] and c["level"] == 2 and landing.get(c["slug"], 0) == 0]
    if empty:
        warnings.append(f"{len(empty)} active shelves will hold no products "
                        f"(they render as 'Coming soon'): {', '.join(sorted(empty))}")
    return problems, warnings


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def report(cats, prods, schema_applied):
    by_id = {c["id"]: c for c in cats}
    by_slug = {c["slug"]: c for c in cats if c.get("slug")}
    prod_by_id = {p["id"]: p for p in prods}

    def shelf(slug):
        """Display name post-apply; the slug itself in preview mode."""
        return by_slug.get(slug, {}).get("name") or slug

    if not schema_applied:
        print("\n" + "=" * 76)
        print("  MAPPING PREVIEW -- the category tree is not applied to this database yet.")
        print("  Destinations are shown by slug and are not validated against the DB.")
        print("=" * 76)

    print("\n=== PRODUCT REMAP =========================================================")
    print(f"{'id':>4}  {'product':<44} {'from':<24} -> to")
    print("-" * 106)
    moved = kept = 0
    for pid in sorted(PRODUCT_MAP):
        slug, label = PRODUCT_MAP[pid]
        live = prod_by_id.get(pid)
        old = by_id.get(live["main_category_id"], {}).get("name", "?") if live else "?"
        new = shelf(slug)
        if old == new:
            kept += 1
        else:
            moved += 1
        print(f"{pid:>4}  {label[:44]:<46}{old[:24]:<24} -> {new}")

    print(f"\n{'':>4}  WITHDRAWN (is_active = false, nothing deleted)")
    for pid, label in sorted(RETIRE_PRODUCTS.items()):
        old = by_id.get(prod_by_id.get(pid, {}).get("main_category_id"), {}).get("name", "?")
        print(f"{pid:>4}  {label[:44]:<46}{old[:24]:<24} -> withdrawn")

    print(f"\n  {moved} products move, {kept} stay put, {len(RETIRE_PRODUCTS)} withdrawn")

    print("\n=== SHELF COUNTS, BEFORE AND AFTER ========================================")
    before = Counter()
    for p in prods:
        before[by_id.get(p["main_category_id"], {}).get("name", "?")] += 1
    after = Counter()
    for slug, _ in PRODUCT_MAP.values():
        after[shelf(slug)] += 1

    print(f"  {'BEFORE':<30}{'':>5}   {'AFTER':<30}")
    print("-" * 74)
    rows = max(len(before), len(after))
    b = sorted(before.items(), key=lambda x: -x[1])
    a = sorted(after.items(), key=lambda x: -x[1])
    for i in range(rows):
        lb = f"{b[i][0][:28]:<30}{b[i][1]:>4}" if i < len(b) else " " * 34
        la = f"{a[i][0][:28]:<30}{a[i][1]:>4}" if i < len(a) else ""
        print(f"  {lb}   {la}")
    print(f"\n  {len(before)} shelves in use before -> {len(after)} after "
          f"({sum(after.values())} active SKUs)")

    if BANNER_NOTES:
        print("\n=== BANNERS TO EYEBALL ====================================================")
        for bid, note in BANNER_NOTES.items():
            print(f"  banner {bid}: {note}")


# ---------------------------------------------------------------------------
# SQL generation
# ---------------------------------------------------------------------------

def emit_sql():
    ids = sorted(PRODUCT_MAP)
    lines = []
    for i, pid in enumerate(ids):
        slug, label = PRODUCT_MAP[pid]
        comma = "," if i < len(ids) - 1 else " "
        lines.append(f"  ({pid:>3}, '{slug}'){comma}{'':<{max(0, 22 - len(slug))}}-- {label}")
    body = "\n".join(lines)
    retire = ", ".join(str(p) for p in sorted(RETIRE_PRODUCTS))
    retire_comment = "\n".join(
        f"--   {pid}: {label}" for pid, label in sorted(RETIRE_PRODUCTS.items()))

    return f"""\
-- Phase 3 of the category taxonomy work. See docs/category-system-plan.md §3.5.
--
-- GENERATED FROM supabase/tools/category_backfill.py -- do not hand-edit. Change the
-- mapping there and re-run `python3 supabase/tools/category_backfill.py --emit-sql`.
--
-- Moves every product onto the new tree and withdraws two SKUs. Nothing is deleted:
-- withdrawal is `is_active = false`, which keeps each product's variants, images, info,
-- highlights and hand-built Hindi voice aliases intact.
--
-- Run the dry run first -- it prints this whole remap against live data and refuses to
-- proceed if any product would land on an umbrella, a non-leaf or a missing shelf:
--
--     python3 supabase/tools/category_backfill.py

begin;

-- ---------------------------------------------------------------------------
-- 1. Remap
-- ---------------------------------------------------------------------------

update public.products p
   set main_category_id = c.id
  from (values
{body}
) as v(product_id, slug)
  join public.main_category c on c.slug = v.slug
 where p.id = v.product_id
   and p.main_category_id is distinct from c.id;

-- ---------------------------------------------------------------------------
-- 2. Withdraw the two consumer gadgets
-- ---------------------------------------------------------------------------
--
{retire_comment}
--
-- DxMart is a grocery and daily-essentials shop. These stay in the database, keep every
-- child row, and come back with a single `is_active = true` if that changes.

update public.products
   set is_active = false
 where id in ({retire});

-- ---------------------------------------------------------------------------
-- 3. Assertions
-- ---------------------------------------------------------------------------

do $$
declare
  n_on_umbrella int; n_unfiled int; n_active int; n_shelves int;
begin
  select count(*) into n_on_umbrella
    from public.products p
    join public.main_category c on c.id = p.main_category_id
   where c.level < 2;
  if n_on_umbrella > 0 then
    raise exception '% products are filed on an umbrella, not a shelf', n_on_umbrella;
  end if;

  select count(*) into n_unfiled
    from public.products p
    join public.main_category c on c.id = p.main_category_id
   where c.slug = 'uncategorised' and p.is_active;
  select count(*) into n_active from public.products where is_active;
  if n_active > 0 and n_unfiled::numeric / n_active > {UNCATEGORISED_CEILING} then
    raise exception
      'Uncategorised holds % of % active SKUs, over the 2%% ceiling -- the tree is wrong',
      n_unfiled, n_active;
  end if;

  select count(distinct main_category_id) into n_shelves
    from public.products where is_active;
  raise notice
    'category backfill: % active SKUs across % shelves, % unfiled', n_active, n_shelves, n_unfiled;
end;
$$;

commit;
"""


def check_sql_in_sync():
    if not MIGRATION.exists():
        return [f"{MIGRATION.name} does not exist -- run with --emit-sql"]
    on_disk = MIGRATION.read_text()
    if on_disk.strip() != emit_sql().strip():
        return [f"{MIGRATION.name} is out of sync with the mapping -- re-run --emit-sql"]
    return []


# ---------------------------------------------------------------------------

def verify(cats, prods):
    """Post-apply check: assert the live database now matches the mapping."""
    by_id = {c["id"]: c for c in cats}
    bad = []
    for pid, (slug, label) in sorted(PRODUCT_MAP.items()):
        p = next((x for x in prods if x["id"] == pid), None)
        if p is None:
            bad.append(f"product {pid} '{label}' is missing")
            continue
        actual = by_id.get(p["main_category_id"], {}).get("slug")
        if actual != slug:
            bad.append(f"product {pid} '{label}' is on '{actual}', expected '{slug}'")
        if not p.get("is_active", True):
            bad.append(f"product {pid} '{label}' should be active but is not")
    for pid, label in sorted(RETIRE_PRODUCTS.items()):
        p = next((x for x in prods if x["id"] == pid), None)
        if p and p.get("is_active", True):
            bad.append(f"product {pid} '{label}' should be withdrawn but is still active")
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true",
                   help="print the remap and check it (default)")
    g.add_argument("--emit-sql", action="store_true",
                   help=f"regenerate {MIGRATION.name} from the mapping above")
    g.add_argument("--verify", action="store_true",
                   help="assert the live database matches the mapping (run after apply)")
    args = ap.parse_args()

    if args.emit_sql:
        MIGRATION.write_text(emit_sql())
        print(f"wrote {MIGRATION.relative_to(REPO)}")
        return 0

    url, key = credentials()
    print(f"reading {url}")
    cats, prods, schema_applied = load(url, key)
    print(f"  {len(cats)} categories, {len(prods)} products")

    if args.verify:
        if not schema_applied:
            print("\nVERIFY FAILED: the category tree is not applied to this database.")
            return 1
        bad = verify(cats, prods)
        if bad:
            print("\nVERIFY FAILED:")
            for b in bad:
                print(f"  ! {b}")
            return 1
        print(f"\nVERIFY OK -- all {len(PRODUCT_MAP)} products on their mapped shelf, "
              f"{len(RETIRE_PRODUCTS)} withdrawn")
        return 0

    problems, warnings = check(cats, prods, schema_applied)
    problems += check_sql_in_sync()

    if not problems:
        report(cats, prods, schema_applied)

    if warnings:
        print("\n=== NOTES =================================================================")
        for w in warnings:
            print(f"  - {w}")

    if problems:
        print("\n=== PROBLEMS ==============================================================")
        for p in problems:
            print(f"  ! {p}")
        print(f"\n{len(problems)} problem(s). Nothing would be applied.")
        return 1

    if not schema_applied:
        print("\nMapping preview clean. Next: apply 20260731000001 and ...02, then re-run")
        print("this dry run to validate the destinations against the real tree.")
        return 0

    print("\nDry run clean. Apply with the migration, not this tool:")
    print(f"  supabase db push          # applies {MIGRATION.name}")
    print("  python3 supabase/tools/category_backfill.py --verify")
    return 0


if __name__ == "__main__":
    sys.exit(main())
