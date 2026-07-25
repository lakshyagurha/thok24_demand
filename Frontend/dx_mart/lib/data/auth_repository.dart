import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';

/// Phone/OTP authentication.
///
/// Replaces `auth/login.php`, `signup.php`, `verify_otp.php`, `forget_password.php`,
/// `reset_password.php` and the `otp_table` — Supabase Auth issues, stores and expires
/// OTPs itself, so none of that is app code any more.
///
/// The old flow was email + password, and every one of those PHP files built its SQL by
/// string interpolation. It also returned the full user row — including the bcrypt
/// password hash — to the client on login.
class AuthRepository {
  const AuthRepository();

  SupabaseClient get _db => Db.client;

  /// Normalises to E.164, which is what Supabase expects. Users type "9876543210";
  /// India (+91) is assumed when no country code is given.
  static String normalisePhone(String input, {String countryCode = '+91'}) {
    final digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.length > 10 && digits.startsWith('91')) return '+$digits';
    return '$countryCode$digits';
  }

  static bool isValidIndianMobile(String input) =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(input.replaceAll(RegExp(r'\D'), ''));

  /// Sends a login OTP. The same call signs in an existing user and registers a new one,
  /// so there is no separate signup endpoint to keep in step.
  Future<void> sendOtp(String phone) async {
    try {
      await _db.auth.signInWithOtp(phone: normalisePhone(phone));
    } on AuthException catch (e) {
      throw DataException(e.message);
    }
  }

  /// Verifies the code and establishes the session. [name] is stored on the profile for
  /// first-time users via the database's handle_new_user trigger.
  Future<void> verifyOtp({
    required String phone,
    required String token,
    String? name,
  }) async {
    try {
      final res = await _db.auth.verifyOTP(
        phone: normalisePhone(phone),
        token: token.trim(),
        type: OtpType.sms,
      );
      if (res.session == null) throw DataException('Could not verify the code.');

      if (name != null && name.trim().isNotEmpty) {
        await updateProfile(name: name.trim());
      }
    } on AuthException catch (e) {
      throw DataException(e.message);
    }
  }

  /// Email + password sign in. Interim path alongside phone/OTP: while the SMS provider
  /// (MSG91, via the Send SMS auth hook) is being configured, this lets the app be tested
  /// end to end without an SMS round trip. Phone/OTP remains the primary flow — this does
  /// not replace it, and both create the same kind of Supabase Auth session.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _db.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.session == null) throw DataException('Could not sign in.');
    } on AuthException catch (e) {
      throw DataException(e.message);
    }
  }

  /// Returns true if a session was created immediately. Returns false if the project
  /// requires email confirmation and a link was sent instead — the caller should tell the
  /// user to check their inbox and then sign in. [name] goes straight into signUp's user
  /// metadata, which handle_new_user picks up when it creates the profile row, so no
  /// separate updateProfile call is needed here (unlike the phone flow, where verifyOTP
  /// has no metadata parameter).
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final res = await _db.auth.signUp(
        email: email.trim(),
        password: password,
        data: (name != null && name.trim().isNotEmpty)
            ? {'name': name.trim()}
            : null,
      );
      return res.session != null;
    } on AuthException catch (e) {
      throw DataException(e.message);
    }
  }

  Future<void> signOut() => _db.auth.signOut();

  bool get isSignedIn => Db.isSignedIn;

  /// Emits on sign-in, sign-out and token refresh, so the UI can react instead of each
  /// screen re-deriving who the user is.
  Stream<AuthState> get onAuthStateChange => _db.auth.onAuthStateChange;

  /// The signed-in user's profile. No id argument, and RLS returns only their own row.
  Future<Map<String, dynamic>?> currentProfile() async {
    final id = Db.currentUserId;
    if (id == null) return null;
    return await _db
        .from('user_profiles')
        .select('id, name, phone, status')
        .eq('id', id)
        .maybeSingle();
  }

  Future<void> updateProfile({String? name, String? phone}) async {
    final id = Db.currentUserId;
    if (id == null) throw DataException('Not signed in.');
    // Null-aware map entries: an entry whose value is null is omitted, so a caller can
    // update just the name without blanking the phone.
    final values = <String, dynamic>{
      'name': ?name,
      'phone': ?phone,
    };
    if (values.isEmpty) return;
    // The UPDATE policy carries WITH CHECK as well as USING, so this cannot be turned
    // into a write against somebody else's profile.
    await _db.from('user_profiles').update(values).eq('id', id);
  }
}
