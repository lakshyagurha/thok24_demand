import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';

/// The one text field.
///
/// The app had four: `CustomTextField` (correct, and used only in Auth and the
/// location screen), the address form's — which set `BorderSide.none` on every
/// border state, so it could never show focus or validation, and had no `style`
/// for the typed text at all — the cart's coupon input, and the rating sheet's
/// bare `OutlineInputBorder`.
///
/// A label above the field rather than a floating one: floating labels are
/// harder to scan in Devanagari, where the matra above the glyph competes with
/// the label's descender.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.obscureText = false,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: AppText.label(color: AppColors.textSecondary)),
          AppSpace.gapH(AppSpace.sm),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          enabled: enabled,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          style: AppText.bodyL(),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            filled: true,
            fillColor: enabled ? AppColors.surface : AppColors.surfaceSunken,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 20, color: AppColors.iconMuted),
            suffixIcon: suffix,
            hintStyle: AppText.bodyM(color: AppColors.textTertiary),
            contentPadding: AppSpace.symmetric(
              horizontal: AppSpace.base,
              vertical: AppSpace.md,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : AppColors.primary,
                width: 1.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        if (hasError) ...[
          AppSpace.gapH(AppSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 14, color: AppColors.danger),
              AppSpace.gapW(AppSpace.xs),
              Expanded(
                child: Text(errorText!,
                    style: AppText.caption(color: AppColors.danger)),
              ),
            ],
          ),
        ] else if (helper != null) ...[
          AppSpace.gapH(AppSpace.xs),
          Text(helper!, style: AppText.caption()),
        ],
      ],
    );
  }
}
