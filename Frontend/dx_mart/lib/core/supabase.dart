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
