import 'package:flutter/services.dart';

/// Haptics, named by what they confirm rather than by intensity.
///
/// Deliberately not wired into [AppButton] or any other shared component that
/// fires on every tap — most taps are navigation, and a click on every one of
/// them would numb the effect instead of signalling anything. Call sites pick
/// one of these explicitly, only where a state actually changed or where the
/// user may not be looking at the screen (BolKeOrder's mic).
///
/// `HapticFeedback` calls route through the OS, so a user who has disabled
/// system haptics (iOS) or touch vibration (Android) gets silence for free —
/// there is no separate opt-out to build here.
class AppHaptics {
  const AppHaptics._();

  /// Picking between options: qty stepper steps, payment method, delivery
  /// slot, pull-to-refresh trigger.
  static void selection() => HapticFeedback.selectionClick();

  /// A lightweight action landed: add to cart, wishlist toggle, coupon code
  /// copied, voice mic started/stopped listening.
  static void tap() => HapticFeedback.lightImpact();

  /// A meaningful action completed: order placed, address saved/deleted,
  /// coupon applied, voice order parsed into the bill.
  static void success() => HapticFeedback.mediumImpact();

  /// Something was rejected: order placement failed, invalid coupon, voice
  /// bot couldn't parse the input.
  static void error() => HapticFeedback.vibrate();
}
