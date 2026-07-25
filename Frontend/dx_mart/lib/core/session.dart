import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Auth/loginScreen.dart';
import '../CustomWidgets/cart_provider.dart';
import '../CustomWidgets/wishlist_provider.dart';
import '../data/catalog_repository.dart';
import 'supabase.dart';

/// Set on [MaterialApp] so the session watcher can route from outside the widget tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// SharedPreferences keys that belong to whoever was signed in, and must not survive
/// into the next person's session on a shared device.
///
/// `selected_address_full` in particular is the previous user's full street address. It
/// was written on every address selection, never read anywhere, and never cleared.
const _userScopedPrefKeys = <String>[
  'selected_address_id',
  'selected_address_full',
];

/// Everything that has to be forgotten when a session ends.
///
/// Sign-out used to clear only the Supabase session and the in-memory cart, and only
/// from the Profile screen — so a session that expired, was revoked, or failed to refresh
/// left all of this behind.
Future<void> clearLocalSessionState(
  CartProvider? cart, [
  WishlistProvider? wishlist,
]) async {
  cart?.clearCart();
  wishlist?.clear();
  // Global settings are not user-scoped, but dropping them costs one request and avoids
  // any chance of a stale value outliving a session.
  CatalogRepository.invalidateSettings();
  final prefs = await SharedPreferences.getInstance();
  for (final key in _userScopedPrefKeys) {
    await prefs.remove(key);
  }
  // `selected_district_name` / `selected_city_name` deliberately survive: the delivery
  // area is a device-level display preference, not identity, and clearing it would send
  // every returning user back through the location picker. Same for `language_code`.
}

/// True once a delivery area has been chosen on this device.
///
/// Splash used this to skip the location picker for a returning user, but the two login
/// screens pushed [LocationScreen] unconditionally — so relaunching the app went straight
/// in while signing in made you re-do GPS. Both paths now ask the same question.
Future<bool> hasChosenDeliveryArea() async {
  final prefs = await SharedPreferences.getInstance();
  final district = prefs.getString('selected_district_name');
  final city = prefs.getString('selected_city_name');
  return district != null &&
      district.isNotEmpty &&
      city != null &&
      city.isNotEmpty;
}

/// Watches the Supabase auth stream and reacts to a session ending.
///
/// `AuthRepository.onAuthStateChange` existed but had **zero subscribers**, so when a
/// refresh token expired or was revoked, `currentUser` went null underneath an
/// already-built widget tree. Navigation still showed the authenticated shell while every
/// query started throwing `Please sign in first.` — an app that looked signed in and
/// worked for nothing. There was no path back either: `signOut()` had exactly one call
/// site, on the Profile screen.
class SessionWatcher extends StatefulWidget {
  const SessionWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<SessionWatcher> createState() => _SessionWatcherState();
}

class _SessionWatcherState extends State<SessionWatcher> {
  StreamSubscription<AuthState>? _sub;

  /// Guards against routing to login repeatedly — `signedOut` can be followed by a
  /// `tokenRefreshFailure` for the same dead session.
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _sub = Db.client.auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        // gotrue signs the user out when a refresh token is rejected, so this covers
        // both an explicit sign-out and an expired or revoked session. (There is no
        // `tokenRefreshFailure` event in gotrue 2.26; transient network failures are
        // retried internally and only a genuine rejection reaches here.)
        case AuthChangeEvent.signedOut:
          _onSessionEnded();
        case AuthChangeEvent.signedIn:
          // A new session invalidates whatever the previous one left in memory. The
          // cart itself lives server-side and RLS scopes it, but the in-memory
          // quantities and row ids are the old user's until something reloads them.
          _redirecting = false;
          context.read<CartProvider>().clearCart();
          context.read<WishlistProvider>().clear();
        default:
          break;
      }
    }, onError: (Object error) {
      // An AuthException on the stream means the session could not be maintained.
      // Without this the stream's error would be unhandled and the user would sit in a
      // shell where every query fails.
      debugPrint('auth stream error: $error');
      if (error is AuthException) _onSessionEnded();
    });
  }

  Future<void> _onSessionEnded() async {
    if (_redirecting) return;
    _redirecting = true;

    await clearLocalSessionState(
      mounted ? context.read<CartProvider>() : null,
      mounted ? context.read<WishlistProvider>() : null,
    );

    // pushAndRemoveUntil, not pushReplacement: the authenticated shell must not stay on
    // the stack, or Android back returns a signed-out user to it.
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
