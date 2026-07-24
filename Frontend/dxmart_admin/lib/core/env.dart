/// Build-time configuration for the internal admin app.
///
/// Replaces the hardcoded LAN IP in `lib/utils/api_constants.dart`
/// (`http://192.168.31.10/api_folder/`), which only ever worked on one office WiFi
/// network and made dev/staging/prod indistinguishable.
///
/// Values come from `--dart-define` so nothing environment-specific is committed:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://asnjjkpjuqsmjqrjojzl.supabase.co \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=`your publishable key`
///
/// For repeatable builds put them in a JSON file and use
/// `--dart-define-from-file=env/dev.json` instead.
///
/// The publishable key is designed to be shipped in client code — it carries no
/// privileges of its own. This app additionally holds NO elevated credentials: every
/// write goes through the `admin-api` Edge Function, which holds the service-role key
/// server-side and checks staff membership itself. The service-role key must NEVER
/// appear here.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Legacy name. Supabase renamed anon keys to publishable keys; both defines are
  /// accepted so existing build scripts keep working.
  static const String _legacyAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static String get supabaseKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _legacyAnonKey;

  /// Public base for product imagery. Rows store a path like `uploads/abc.png`; the
  /// host is applied at read time rather than being baked into the row, which is how
  /// the old data ended up containing `localhost` and `192.168.31.10`.
  ///
  /// TODO(phase-5): Supabase Storage is not configured for this project yet. Until it
  /// is, [legacyImageBase] is what actually resolves existing image paths.
  static const String storageBucket = String.fromEnvironment(
    'SUPABASE_STORAGE_BUCKET',
    defaultValue: 'product-images',
  );

  /// Base URL the legacy PHP backend served `/uploads` from. Only used to render
  /// image paths that were migrated as relative strings; defaults to empty so nothing
  /// silently points back at a LAN IP.
  static const String legacyImageBase = String.fromEnvironment(
    'LEGACY_IMAGE_BASE',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Fails loudly at startup rather than surfacing confusing network errors later.
  static void assertConfigured() {
    if (!isConfigured) {
      throw StateError(
        'Missing SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY. Pass them with --dart-define:\n'
        '  flutter run --dart-define=SUPABASE_URL=... '
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=...',
      );
    }
  }
}
