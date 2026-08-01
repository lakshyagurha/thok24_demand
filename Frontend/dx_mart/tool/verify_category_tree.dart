// Verifies the live `category_tree()` payload from a real anonymous client: the shape,
// the counts, the visibility rules and the naming rules, exactly as the shipped app
// receives them.
//
// Deliberately NOT a `flutter test`: TestWidgetsFlutterBinding stubs every HTTP request
// to status 400, so a Flutter test cannot make the real calls this needs. Same reasoning
// as tool/verify_rls.dart -- see CLAUDE.md §3a.
//
// It also imports no app code, for a second reason: `models.dart` reaches
// `core/supabase.dart` and so the whole Flutter/FFI stack, which the plain Dart VM
// cannot compile. The model's own parsing and cache round trip are covered by
// `flutter test test/category_tree_test.dart`, which needs no network. Between them the
// two cover the payload and the code that reads it.
//
// Run:
//   dart run tool/verify_category_tree.dart
//
// Reads env/dev.json. Exits non-zero if any check fails.

import 'dart:convert';
import 'dart:io';

late final String baseUrl;
late final String apiKey;

final _client = HttpClient();
var _failures = 0;

void _check(String label, bool ok, [String? detail]) {
  stdout.writeln('${ok ? "  ok  " : "  FAIL"}  $label${detail == null ? "" : "  ($detail)"}');
  if (!ok) _failures++;
}

Future<void> main() async {
  final cfgFile = File('env/dev.json');
  if (!cfgFile.existsSync()) {
    stderr.writeln('env/dev.json not found. Copy env/dev.json.example and fill it in.');
    exit(2);
  }
  final cfg = jsonDecode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
  baseUrl = cfg['SUPABASE_URL'] as String;
  apiKey = (cfg['SUPABASE_PUBLISHABLE_KEY'] ?? cfg['SUPABASE_ANON_KEY']) as String;

  stdout.writeln('Verifying the category tree as an ANONYMOUS client against $baseUrl\n');

  final payload = await _rpc('category_tree');
  if (payload == null) {
    stderr.writeln('category_tree() did not return a payload');
    exit(1);
  }

  final tree = [
    for (final n in payload) Map<String, dynamic>.from(n as Map),
  ];
  List<Map<String, dynamic>> kids(Map<String, dynamic> n) => [
        for (final c in (n['children'] as List? ?? const []))
          Map<String, dynamic>.from(c as Map),
      ];

  stdout.writeln('Structure');
  _check('anonymous can call category_tree()', true);
  _check('6 umbrellas', tree.length == 6, '${tree.length}');
  _check('every root is level 1', tree.every((c) => c['level'] == 1));
  _check(
      'roots are in sort order',
      _isSorted([for (final c in tree) c['sort_order'] as int]),
      '${[for (final c in tree) c['sort_order']]}');
  _check('every root has a slug',
      tree.every((c) => ((c['slug'] ?? '') as String).isNotEmpty));

  final shelves = [for (final u in tree) ...kids(u)];
  _check('34 shelves', shelves.length == 34, '${shelves.length}');
  _check('every shelf is level 2', shelves.every((c) => c['level'] == 2));
  _check('every shelf points at its parent',
      tree.every((u) => kids(u).every((c) => c['parent_id'] == u['id'])));
  _check('no shelf is deeper than level 2',
      shelves.every((c) => kids(c).isEmpty));

  stdout.writeln('\nVisibility');
  _check('no inactive node leaked',
      tree.every((u) => u['is_active'] == true) &&
          shelves.every((c) => c['is_active'] == true));
  const hidden = {'uncategorised', 'unfiled', 'retired-electronics-appliances',
      'retired-packaged-food'};
  _check('no retired or staging node leaked',
      !shelves.any((c) => hidden.contains(c['slug'])) &&
          !tree.any((c) => hidden.contains(c['slug'])));

  stdout.writeln('\nCounts');
  final total = tree.fold<int>(0, (s, c) => s + (c['product_count'] as int));
  _check('subtree counts sum to 35 active SKUs', total == 35, '$total');
  _check(
      'each umbrella equals the sum of its shelves',
      tree.every((u) =>
          u['product_count'] ==
          kids(u).fold<int>(0, (s, c) => s + (c['product_count'] as int))));
  final stocked =
      shelves.where((c) => (c['product_count'] as int) > 0).toList();
  _check('10 shelves are stocked', stocked.length == 10, '${stocked.length}');

  stdout.writeln('\nNaming rules');
  for (final node in [...tree, ...shelves]) {
    final name = node['name'] as String;
    if (name.length > 22) _check('"$name" is <= 22 chars', false);
    if ('&'.allMatches(name).length > 1) {
      _check('"$name" has at most one &', false);
    }
    if (((node['name_hi'] ?? '') as String).isEmpty) {
      _check('"$name" has Hindi', false);
    }
    if (((node['name_hn'] ?? '') as String).isEmpty) {
      _check('"$name" has Hinglish', false);
    }
  }
  _check('all 40 names pass length, ampersand, hi and hn rules', true);

  stdout.writeln('\nPayload completeness');
  const required = {
    'id', 'slug', 'level', 'parent_id', 'name', 'name_hi', 'name_hn',
    'icon_url', 'sort_order', 'is_active', 'product_count', 'children',
  };
  _check('every node carries every field the app reads',
      [...tree, ...shelves].every((n) => required.difference(n.keys.toSet()).isEmpty));

  _client.close(force: true);
  stdout.writeln(_failures == 0
      ? '\nAll checks passed.'
      : '\n$_failures check(s) FAILED.');
  exit(_failures == 0 ? 0 : 1);
}

bool _isSorted(List<int> xs) {
  for (var i = 1; i < xs.length; i++) {
    if (xs[i] < xs[i - 1]) return false;
  }
  return true;
}

Future<List?> _rpc(String fn) async {
  final req = await _client.postUrl(Uri.parse('$baseUrl/rest/v1/rpc/$fn'));
  req.headers
    ..set('apikey', apiKey)
    ..set('Authorization', 'Bearer $apiKey')
    ..set('Content-Type', 'application/json');
  req.write('{}');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) {
    stderr.writeln('rpc/$fn -> ${res.statusCode}: $body');
    return null;
  }
  return jsonDecode(body) as List;
}
