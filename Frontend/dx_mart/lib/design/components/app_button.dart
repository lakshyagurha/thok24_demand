import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_gradients.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

enum AppButtonSize { sm, md, lg }

/// The one button.
///
/// The app had at least eight specifications for "a primary button" — heights
/// of 27, 34, 36, 38, 39, 45 and 48, radii of 7, 8, 12, 25 and 30, and labels
/// that were white in some places and pure black on the green fill in others
/// (about 3.2:1). `CustomButton` existed and was correct, and was used on
/// exactly six screens, none of them in the shopping flow.
///
/// Two things every hand-rolled button got wrong:
///
///  * **No press feedback.** They wrapped an `InkWell` *around* an opaque
///    decorated `Container`, so the ripple painted behind the fill and was
///    never visible. Here the fill is the decoration and `InkWell` sits inside
///    a transparent `Material` on top of it.
///  * **No loading or disabled state**, so screens invented their own — usually
///    swapping the label for a spinner, or turning the whole control
///    `Colors.grey`, which reads as broken rather than "not yet".
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.lg,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;

  bool get _enabled => onPressed != null && !loading;

  double get _height => switch (size) {
        AppButtonSize.sm => AppSpace.buttonHeightCompact,
        AppButtonSize.md => 44,
        AppButtonSize.lg => AppSpace.buttonHeight,
      };

  TextStyle _labelStyle(Color color) => size == AppButtonSize.sm
      ? AppText.buttonCompact(color: color)
      : AppText.button(color: color);

  @override
  Widget build(BuildContext context) {
    final filled = variant == AppButtonVariant.primary ||
        variant == AppButtonVariant.secondary ||
        variant == AppButtonVariant.danger;

    final Color fg = switch (variant) {
      AppButtonVariant.primary => AppColors.onPrimary,
      AppButtonVariant.secondary => AppColors.onSecondary,
      AppButtonVariant.danger => AppColors.textInverse,
      AppButtonVariant.outline => AppColors.primary,
      AppButtonVariant.ghost => AppColors.primary,
    };

    final Gradient? gradient = !_enabled
        ? null
        : switch (variant) {
            AppButtonVariant.primary => AppGradients.primary,
            AppButtonVariant.secondary => AppGradients.secondary,
            _ => null,
          };

    final Color? solid = !_enabled
        ? (filled ? AppColors.disabledSurface : null)
        : variant == AppButtonVariant.danger
            ? AppColors.danger
            : null;

    final Color effectiveFg = _enabled ? fg : AppColors.onDisabled;

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: AppSpace.w(16),
            height: AppSpace.w(16),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
            ),
          ),
          AppSpace.gapW(AppSpace.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: effectiveFg),
          AppSpace.gapW(AppSpace.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _labelStyle(effectiveFg),
          ),
        ),
        if (trailingIcon != null) ...[
          AppSpace.gapW(AppSpace.sm),
          Icon(trailingIcon, size: 18, color: effectiveFg),
        ],
      ],
    );

    return SizedBox(
      width: expand ? double.infinity : null,
      height: AppSpace.h(_height),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          color: solid,
          borderRadius: AppRadius.smAll,
          border: variant == AppButtonVariant.outline
              ? Border.all(
                  color: _enabled ? AppColors.primary : AppColors.border,
                  width: 1.5,
                )
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.smAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _enabled ? onPressed : null,
            child: Padding(
              padding: AppSpace.symmetric(horizontal: AppSpace.base),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
