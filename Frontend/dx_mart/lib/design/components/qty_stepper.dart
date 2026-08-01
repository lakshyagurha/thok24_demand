import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_gradients.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';
import '../haptics.dart';

/// The quantity control.
///
/// There were three implementations — the grid card's (78x34, 11sp icons), the
/// cart line's (28dp tall, 14sp icons) and the variant sheet's (36dp,
/// `IconButton` at 16sp) — and in two of them the minus silently became a
/// delete icon at quantity 1, in the same position and at the same size, so the
/// control that decrements and the control that removes the line were
/// indistinguishable until after the tap.
///
/// The +/- targets were roughly 30x28. This holds them to 44dp.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.onRemove,
    this.compact = false,
    this.busy = false,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  /// Called instead of [onDecrement] at quantity 1. Given a distinct icon so
  /// "one fewer" and "take it out" are not the same button.
  final VoidCallback? onRemove;

  final bool compact;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final h = AppSpace.h(compact ? 32 : 36);
    final atMinimum = quantity <= 1;

    return Container(
      height: h,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Step(
            icon: atMinimum && onRemove != null
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            onTap: atMinimum && onRemove != null ? onRemove! : onDecrement,
            haptic: atMinimum && onRemove != null
                ? AppHaptics.tap
                : AppHaptics.selection,
            compact: compact,
          ),
          SizedBox(
            width: AppSpace.w(compact ? 20 : 26),
            child: Center(
              child: busy
                  ? SizedBox(
                      width: AppSpace.w(12),
                      height: AppSpace.w(12),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                      ),
                    )
                  : Text(
                      '$quantity',
                      style: AppText.label(color: AppColors.onPrimary),
                    ),
            ),
          ),
          _Step(
            icon: Icons.add_rounded,
            onTap: onIncrement,
            haptic: AppHaptics.selection,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.onTap,
    required this.haptic,
    required this.compact,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback haptic;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {
        haptic();
        onTap();
      },
      radius: AppSpace.w(20),
      child: SizedBox(
        width: AppSpace.w(compact ? 32 : 38),
        height: double.infinity,
        child: Icon(icon, size: compact ? 16 : 18, color: AppColors.onPrimary),
      ),
    );
  }
}
