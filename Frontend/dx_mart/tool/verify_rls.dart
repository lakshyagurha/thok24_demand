// Verifies the security model from a real client, using the publishable key the app
// ships with.
//
// This is deliberately NOT a `flutter test`: TestWidgetsFlutterBinding stubs every HTTP
// request to status 400, so a Flutter test cannot make the real network calls this needs.
// It talks to the PostgREST endpoint directly -- the same API supabase_flutter uses -- so
// what it proves is exactly what the shipped app is subject to.
//
// Run:
//   dart run tool/verify_rls.dart
//
// Reads env/dev.json. Exits non-zero if any check fails.

import 'dart:convert';
import 'dart:io';

late final String baseUrl;
late final String apiKey;

final _client = HttpClient();
var _failures = 0;

Future<void> main() async {
  final cfgFile = File('env/dev.json');
  if (!cfgFile.existsSync()) {
    stderr.writeln('env/dev.json not found. Copy env/dev.json.example and fill it in.');
    exit(2);
  }
  final cfg = jsonDecode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
  baseUrl = cfg['SUPABASE_URL'] as String;
  apiKey = (cfg['SUPABASE_PUBLISHABLE_KEY'] ?? cfg['SUPABASE_ANON_KEY']) as String;

  stdout.writeln('Verifying as an ANONYMOUS client against $baseUrl\n');

  // The catalog must be browsable before sign-in.
  await _expectOk('anonymous can read categories', 'main_category?select=id,name');
  await _expectOk('anonymous can read products', 'products?select=id,name&limit=5');
  await _expectOk('anonymous can read variants', 'product_variants?select=id,selling_price&limit=5');
  await _expectOk('anonymous can read voice aliases', 'product_aliases?select=alias&limit=5');
  await _expectOk('anonymous can read app settings', 'app_settings?select=key,value');

  // User-owned data must be invisible. In the old backend each of these was reachable by
  // putting somebody else's user_id in the request.
  await _expectEmpty('anonymous sees NO cart rows', 'cart_items?select=id');
  await _expectEmpty('anonymous sees NO orders', 'orders?select=id');
  await _expectEmpty('anonymous sees NO addresses', 'delivery_address?select=id');
  await _expectEmpty('anonymous sees NO wishlist rows', 'wishlist?select=id');
  await _expectEmpty('anonymous sees NO chat history', 'chat_messages?select=id');
  await _expectEmpty('anonymous sees NO profiles', 'user_profiles?select=id');

  // Rider names, mobiles and home addresses: no policy, no grant.
  await _expectDenied('rider PII (delivery_boy) is denied', 'delivery_boy?select=name,mobile');

  // Private coupon codes must not be enumerable.
  await _expectNoPrivateCoupons();

  // Writes must be impossible from a client.
  await _expectWriteDenied('catalog write is denied', 'products', {
    'name': 'injected',
    'main_category_id': 1,
  });
  await _expectWriteDenied('self-priced order insert is denied', 'orders', {
    'user_id': '11111111-1111-1111-1111-111111111111',
    'total_amount': 999,
    'final_amount': 0.01,
  });

  stdout.writeln();
  if (_failures == 0) {
    stdout.writeln('All checks passed.');
    exit(0);
  }
  stderr.writeln('$_failures check(s) FAILED.');
  exit(1);
}

Future<(int, String)> _get(String path) async {
  final req = await _client.getUrl(Uri.parse('$baseUrl/rest/v1/$path'));
  req.headers
    ..set('apikey', apiKey)
    ..set('Authorization', 'Bearer $apiKey');
  final res = await req.close();
  return (res.statusCode, await res.transform(utf8.decoder).join());
}

Future<(int, String)> _post(String table, Map<String, dynamic> body) async {
  final req = await _client.postUrl(Uri.parse('$baseUrl/rest/v1/$table'));
  req.headers
    ..set('apikey', apiKey)
    ..set('Authorization', 'Bearer $apiKey')
    ..set('Content-Type', 'application/json');
  req.write(jsonEncode(body));
  final res = await req.close();
  return (res.statusCode, await res.transform(utf8.decoder).join());
}

void _pass(String label) => stdout.writeln('  PASS  $label');

void _fail(String label, String detail) {
  _failures++;
  stdout.writeln('  FAIL  $label  -> $detail');
}

Future<void> _expectOk(String label, String path) async {
  final (code, body) = await _get(path);
  if (code == 200) {
    _pass('$label (${(jsonDecode(body) as List).length} rows)');
  } else {
    _fail(label, 'HTTP $code $body');
  }
}

Future<void> _expectEmpty(String label, String path) async {
  final (code, body) = await _get(path);
  if (code != 200) {
    // A hard permission error is an equally good outcome here.
    _pass('$label (denied, HTTP $code)');
    return;
  }
  final rows = jsonDecode(body) as List;
  rows.isEmpty ? _pass(label) : _fail(label, '${rows.length} rows LEAKED: $body');
}

Future<void> _expectDenied(String label, String path) async {
  final (code, body) = await _get(path);
  if (code == 200) {
    final rows = jsonDecode(body) as List;
    rows.isEmpty
        ? _pass('$label (readable but empty)')
        : _fail(label, '${rows.length} rows LEAKED: $body');
    return;
  }
  _pass('$label (HTTP $code)');
}

Future<void> _expectNoPrivateCoupons() async {
  const label = 'private coupon codes are not enumerable';
  final (code, body) = await _get('coupon?select=code_name,status');
  if (code != 200) {
    _pass('$label (denied, HTTP $code)');
    return;
  }
  final rows = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
  final leaked = rows.where((r) => r['status'] != 'Public').toList();
  leaked.isEmpty
      ? _pass('$label (${rows.length} public coupon(s) visible)')
      : _fail(label, 'non-public coupons visible: $leaked');
}

Future<void> _expectWriteDenied(
  String label,
  String table,
  Map<String, dynamic> body,
) async {
  final (code, res) = await _post(table, body);
  (code >= 200 && code < 300)
      ? _fail(label, 'write SUCCEEDED (HTTP $code)')
      : _pass('$label (HTTP $code)');
}
