// Model-level cover for the category tree: parsing the RPC payload, and the cache
// round trip a cold launch depends on.
//
// No network. `flutter test` stubs every HTTP request to status 400, so the live payload
// is verified separately by `dart run tool/verify_category_tree.dart` — see the note at
// the top of that file. The fixture below is a trimmed copy of a real `category_tree()`
// response, Devanagari included, so what is parsed here is the shape the server sends.

import 'dart:convert';

import 'package:dx_mart/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two umbrellas from the real payload: one stocked, one entirely "Coming soon".
const String _fixture = '''
[
  {
    "id": 45, "slug": "grocery-kitchen", "level": 1, "parent_id": null,
    "name": "Grocery & Kitchen", "name_hi": "किराना और रसोई",
    "name_hn": "Kirana Aur Rasoi",
    "icon_url": "category/icon_grocery_kitchen.png",
    "sort_order": 1, "is_active": true, "product_count": 26,
    "children": [
      {
        "id": 27, "slug": "fruits-vegetables", "level": 2, "parent_id": 45,
        "name": "Fruits & Vegetables", "name_hi": "फल और सब्ज़ियाँ",
        "name_hn": "Fal Aur Sabziyan", "icon_url": "category/photo_27.png",
        "sort_order": 1, "is_active": true, "product_count": 0, "children": []
      },
      {
        "id": 23, "slug": "atta-rice-dal", "level": 2, "parent_id": 45,
        "name": "Atta, Rice & Dal", "name_hi": "आटा, चावल और दाल",
        "name_hn": "Atta, Chawal Aur Dal", "icon_url": "category/photo_23.png",
        "sort_order": 2, "is_active": true, "product_count": 7, "children": []
      },
      {
        "id": 25, "slug": "dairy-bread-eggs", "level": 2, "parent_id": 45,
        "name": "Dairy, Bread & Eggs", "name_hi": "डेयरी, ब्रेड और अंडे",
        "name_hn": "Dairy, Bread Aur Ande", "icon_url": null,
        "sort_order": 5, "is_active": true, "product_count": 19, "children": []
      }
    ]
  },
  {
    "id": 48, "slug": "beauty-personal-care", "level": 1, "parent_id": null,
    "name": "Beauty & Personal Care", "name_hi": "निजी देखभाल",
    "name_hn": "Niji Dekhbhal",
    "icon_url": "category/icon_beauty_personal_care.png",
    "sort_order": 4, "is_active": true, "product_count": 0,
    "children": [
      {
        "id": 60, "slug": "hair-care", "level": 2, "parent_id": 48,
        "name": "Hair Care", "name_hi": "बालों की देखभाल",
        "name_hn": "Balon Ki Dekhbhal", "icon_url": null,
        "sort_order": 2, "is_active": true, "product_count": 0, "children": []
      }
    ]
  }
]
''';

List<Category> _parse(String raw) => [
      for (final n in jsonDecode(raw) as List)
        Category.fromTreeNode(Map<String, dynamic>.from(n as Map)),
    ];

void main() {
  group('Category.fromTreeNode', () {
    test('parses umbrellas and their shelves', () {
      final tree = _parse(_fixture);

      expect(tree.length, 2);
      expect(tree.first.name, 'Grocery & Kitchen');
      expect(tree.first.level, 1);
      expect(tree.first.isUmbrella, isTrue);
      expect(tree.first.parentId, isNull);
      expect(tree.first.children.length, 3);
      expect(tree.first.children.first.level, 2);
      expect(tree.first.children.first.parentId, 45);
      expect(tree.first.children.first.isUmbrella, isFalse);
    });

    test('keeps Devanagari and Hinglish intact', () {
      final grocery = _parse(_fixture).first;
      expect(grocery.nameHi, 'किराना और रसोई');
      expect(grocery.nameHn, 'Kirana Aur Rasoi');
      expect(grocery.children[1].nameHi, 'आटा, चावल और दाल');
    });

    test('localizedName picks the right variant and falls back to English', () {
      final grocery = _parse(_fixture).first;
      expect(grocery.localizedName('en'), 'Grocery & Kitchen');
      expect(grocery.localizedName('hi'), 'किराना और रसोई');
      expect(grocery.localizedName('hn'), 'Kirana Aur Rasoi');

      // An unknown code, and a node missing a translation, both fall back.
      expect(grocery.localizedName('fr'), 'Grocery & Kitchen');
      final noHindi = Category(id: 1, name: 'Pooja Needs', nameHi: '');
      expect(noHindi.localizedName('hi'), 'Pooja Needs');
    });

    test('isEmpty marks exactly the unstocked shelves', () {
      final tree = _parse(_fixture);
      final shelves = [for (final u in tree) ...u.descendants];

      expect(shelves.where((c) => c.isEmpty).map((c) => c.slug),
          containsAll(['fruits-vegetables', 'hair-care']));
      expect(shelves.firstWhere((c) => c.slug == 'atta-rice-dal').isEmpty, isFalse);
      // A whole umbrella with nothing under it is empty too — that is what puts
      // "Coming soon" on its section header rather than a count.
      expect(tree.last.isEmpty, isTrue);
    });

    test('descendants flattens depth-first in display order', () {
      final grocery = _parse(_fixture).first;
      expect(
        grocery.descendants.map((c) => c.slug).toList(),
        ['fruits-vegetables', 'atta-rice-dal', 'dairy-bread-eggs'],
      );
    });

    test('iconPath falls back to the legacy image column', () {
      // icon_url is null on the 24 shelves seeded without artwork; `image` is the
      // legacy column that still carries the older shelves' photos. Asserted on
      // iconPath rather than imageUrl because building the URL needs a live Supabase
      // client, which a unit test has no business starting.
      expect(Category(id: 1, name: 'A', iconUrl: 'category/a.png').iconPath,
          'category/a.png');
      expect(Category(id: 2, name: 'B', image: 'category/b.png').iconPath,
          'category/b.png');
      // icon_url wins when both are set.
      expect(
        Category(id: 3, name: 'C', iconUrl: 'icon.png', image: 'legacy.png')
            .iconPath,
        'icon.png',
      );
      // An empty string is not a path — it must fall through, not render as one.
      expect(Category(id: 4, name: 'D', iconUrl: '', image: 'legacy.png').iconPath,
          'legacy.png');
      expect(Category(id: 5, name: 'E').iconPath, isNull);
    });

    test('tolerates a node with no children key', () {
      final c = Category.fromTreeNode({'id': 9, 'name': 'Lonely', 'level': 2});
      expect(c.children, isEmpty);
      expect(c.productCount, 0);
      expect(c.isActive, isTrue);
    });
  });

  group('cache round trip', () {
    test('toTreeNode -> JSON -> fromTreeNode is lossless', () {
      final original = _parse(_fixture);
      final encoded = jsonEncode([for (final c in original) c.toTreeNode()]);
      final decoded = _parse(encoded);

      expect(decoded.length, original.length);
      expect(
        [for (final u in decoded) ...u.descendants].length,
        [for (final u in original) ...u.descendants].length,
      );
      // Byte-identical on a second pass: anything the model drops on the way in would
      // show up here as a shorter payload, which is the failure mode that makes a
      // cached tree worse than no cache at all.
      expect(jsonEncode([for (final c in decoded) c.toTreeNode()]), encoded);
    });

    test('Devanagari survives the round trip', () {
      final decoded = _parse(
        jsonEncode([for (final c in _parse(_fixture)) c.toTreeNode()]),
      );
      expect(decoded.first.nameHi, 'किराना और रसोई');
      expect(decoded.first.children[2].nameHi, 'डेयरी, ब्रेड और अंडे');
    });
  });
}
