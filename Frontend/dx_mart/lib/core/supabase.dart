import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Supabase bootstrap and the single client every repository uses.
///
/// Call [init] once from `main()` before `runApp`.
class Db {
  const Db._();

  static Future<void> init() async {
    Env.assertConfigured();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
      // Sessions persist and refresh automatically, so the app no longer re-identifies
      // the user from an email stored in SharedPreferences on every screen.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  /// The signed-in user's id, or null. Repositories never accept a user id as an
  /// argument: identity comes from the session and is enforced again by RLS in the
  /// database, so a caller cannot ask for someone else's data.
  static String? get currentUserId => client.auth.currentUser?.id;

  static bool get isSignedIn => currentUserId != null;

  /// Resolves a stored image path to a full URL. Accepts values that are already
  /// absolute so rows migrated from the old backend keep working.
  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return client.storage.from(Env.storageBucket).getPublicUrl(path);
  }
}

/// Thrown by repositories for problems worth showing the user.
class DataException implements Exception {
  DataException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A random v4 UUID.
///
/// Used for the place-order idempotency key. `uuid` is not a dependency and pulling one
/// in for a single call site is not worth it; `Random.secure` is a CSPRNG and uniqueness
/// is all this needs.
String newUuidV4() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant 10xx
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Turns an Edge Function non-2xx into a [DataException] carrying the server's own
/// message.
///
/// `functions.invoke` throws [FunctionException] for any status >= 400, and nothing in
/// the app caught it — so every deliberate 400 from place-order ("Coupon has expired",
/// "Only 2 left of ...") was swallowed by a generic catch and shown to the customer as
/// "Could not place the order. Please try again."
Never rethrowFunctionError(Object error, String fallback) {
  if (error is FunctionException) {
    final details = error.details;
    final message = details is Map ? details['message'] : null;
    throw DataException(message is String && message.isNotEmpty ? message : fallback);
  }
  if (error is DataException) throw error;
  throw DataException(fallback);
}
