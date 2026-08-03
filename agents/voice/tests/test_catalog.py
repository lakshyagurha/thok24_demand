"""Regression tests for the catalog snapshot the model actually reads.

This exists because of a real, observed failure: asked for "do kilo aata", the
model added *Bhagyalakshmi Rice Flour*. That product carries the auto-generated
alias "flour" and happens to have a 2 Kg variant, while the actual atta only
comes in 5 kg and 10 kg. The aliases in this catalog were produced by splitting
product titles on whitespace, so they contain a lot of noise and some outright
wrong cross-brand claims.

The snapshot is the agent's entire view of the shop, so a regression here is a
regression in what customers get delivered.

Run: ./.venv/bin/python -m pytest tests/ -q
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from catalog import _render, _useful_alias  # noqa: E402


def _product(pid, name, aliases, variants, category="Atta, Rice & Dal"):
    return {
        "id": pid,
        "name": name,
        "name_hi": None,
        "main_category": {"name": category},
        "product_variants": variants,
        "product_aliases": [{"alias": a} for a in aliases],
    }


class TestUsefulAlias:
    def test_drops_stoplist_tokens(self):
        # These are title fragments, not words anyone says to a shopkeeper.
        for junk in ["for", "pack", "brand", "and", "the", "of"]:
            assert not _useful_alias(junk, 1), junk

    def test_drops_bare_numbers(self):
        assert not _useful_alias("100", 1)
        assert not _useful_alias("500", 1)

    def test_drops_single_characters(self):
        assert not _useful_alias("s", 1)

    def test_drops_aliases_claimed_by_three_or_more_products(self):
        # An alias this widely shared identifies nothing, and pulls the model
        # toward whichever product happens to be listed first. "flour" is the
        # exact token that sent "aata" to a rice flour.
        assert not _useful_alias("flour", 3)
        assert not _useful_alias("amul", 5)

    def test_keeps_aliases_shared_by_two(self):
        # "atta" is legitimately claimed by both atta products. Tightening the
        # rule to >=2 would throw away real Hindi vocabulary.
        assert _useful_alias("atta", 2)
        assert _useful_alias("gehu", 2)

    def test_keeps_ordinary_hindi_vocabulary(self):
        for good in ["aata", "gehu", "daal", "chawal", "moong"]:
            assert _useful_alias(good, 1), good


class TestRender:
    def test_flour_is_dropped_from_rice_flour(self):
        """The original bug, pinned."""
        rows = [
            _product(1, "Bhagyalakshmi Rice Flour", ["flour", "rice"],
                     [{"id": 47, "name": "2 Kg", "selling_price": 80, "stock": 100}]),
            _product(2, "Fortune Chakki Fresh Atta", ["flour", "atta", "gehu"],
                     [{"id": 3, "name": "5 kg", "selling_price": 328, "stock": 99}]),
            _product(7, "Aashirvaad Superior MP Atta", ["flour", "atta"],
                     [{"id": 8, "name": "5 kg", "selling_price": 350, "stock": 50}]),
        ]
        out = _render(rows)
        # "flour" is claimed by all three, so it must not survive anywhere.
        assert "flour" not in out.lower().split("aka:")[1].split("\n")[0]
        # ...while the genuinely discriminating words do.
        assert "atta" in out
        assert "gehu" in out

    def test_product_without_variants_is_omitted(self):
        # Nothing sellable, so offering it can only waste the customer's time.
        rows = [_product(9, "Ghost Product", ["ghost"], [])]
        assert _render(rows) == ""

    def test_variants_are_ordered_cheapest_first(self):
        rows = [
            _product(2, "Fortune Chakki Fresh Atta", ["atta"], [
                {"id": 2, "name": "10 kg", "selling_price": 474, "stock": 87},
                {"id": 3, "name": "5 kg", "selling_price": 328, "stock": 99},
            ])
        ]
        out = _render(rows)
        assert out.index('V3 "5 kg"') < out.index('V2 "10 kg"')

    def test_ids_are_prefixed_so_the_model_cannot_confuse_them(self):
        rows = [
            _product(2, "Fortune Chakki Fresh Atta", ["atta"],
                     [{"id": 3, "name": "5 kg", "selling_price": 328, "stock": 99}])
        ]
        out = _render(rows)
        assert "P2 " in out
        assert 'V3 "5 kg"' in out
        assert "stock:99" in out
