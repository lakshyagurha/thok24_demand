import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Supabase bootstrap for the admin app.
///
/// Call [init] once from `main()` before `runApp`.
///
/// Note the deliberate asymmetry with the consumer app: admin screens never query
/// tables through this client. Catalog tables have no write policy for any client
/// role, so the only data path is the `admin-api` Edge Function (see [AdminApi]).
/// This client exists to hold the session whose JWT authorises those calls.
class Db {
  const Db._();

  static Future<void> init() async {
    Env.assertConfigured();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
      // Sessions persist and refresh automatically, so the app no longer decides who
      // is logged in by reading an email out of SharedPreferences.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Session? get session => client.auth.currentSession;

  static bool get isSignedIn => client.auth.currentUser != null;

  static String? get currentEmail => client.auth.currentUser?.email;

  static Future<void> signOut() => client.auth.signOut();

  /// Resolves a stored image path to a full URL. Accepts values that are already
  /// absolute so rows migrated from the old backend keep working.
  ///
  /// TODO(phase-5): once Supabase Storage is configured, drop the legacy branch and
  /// resolve everything through `client.storage.from(Env.storageBucket)`.
  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (Env.legacyImageBase.isNotEmpty) {
      final base = Env.legacyImageBase.endsWith('/')
          ? Env.legacyImageBase
          : '${Env.legacyImageBase}/';
      return '$base$path';
    }
    return client.storage.from(Env.storageBucket).getPublicUrl(path);
  }
}
