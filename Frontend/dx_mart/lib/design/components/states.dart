import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';
import 'app_button.dart';

/// Empty and error states.
///
/// The app had four empty-state vocabularies and three error mechanisms:
/// a 70sp icon with a green pill CTA, a 48sp icon with a `TextButton.icon`
/// retry, a bare line of grey 13sp text with no icon and no action, and a
/// `const Text("No addresses found.")` at default size and colour. Errors were
/// split across Fluttertoast (with four different background colours),
/// SnackBars in three styles, and inline text — including one screen that
/// substituted the network error into its *empty* copy, so a failed request was
/// presented to the shopper as "you have no orders".
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tone = StateTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final StateTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color surface, Color ink) = switch (tone) {
      StateTone.neutral => (AppColors.surfaceSunken, AppColors.iconMuted),
      StateTone.error => (AppColors.dangerSurface, AppColors.danger),
    };

    return Center(
      child: Padding(
        padding: AppSpace.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSpace.w(72),
              height: AppSpace.w(72),
              decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: ink),
            ),
            AppSpace.gapH(AppSpace.base),
            Text(title, textAlign: TextAlign.center, style: AppText.h3()),
            if (message != null) ...[
              AppSpace.gapH(AppSpace.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppText.bodyM(color: AppColors.textSecondary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              AppSpace.gapH(AppSpace.lg),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.md,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum StateTone { neutral, error }

/// An inline alert, for a problem attached to one part of a form.
///
/// Checkout previously rendered "No address selected" as bold red body text and
/// put the whole error sentence *inside the disabled CTA as its label*, in a
/// fixed 48dp box with no `maxLines`.
class AppAlert extends StatelessWidget {
  const AppAlert({
    super.key,
    required this.message,
    this.tone = AlertTone.warning,
    this.icon,
  });

  final String message;
  final AlertTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (Color surface, Color border, Color ink, IconData fallback) =
        switch (tone) {
      AlertTone.info => (
          AppColors.infoSurface,
          AppColors.infoBorder,
          AppColors.info,
          Icons.info_outline_rounded
        ),
      AlertTone.warning => (
          AppColors.warningSurface,
          AppColors.warningBorder,
          AppColors.warning,
          Icons.error_outline_rounded
        ),
      AlertTone.error => (
          AppColors.dangerSurface,
          AppColors.dangerBorder,
          AppColors.danger,
          Icons.report_gmailerrorred_rounded
        ),
      AlertTone.success => (
          AppColors.successSurface,
          AppColors.successBorder,
          AppColors.success,
          Icons.check_circle_outline_rounded
        ),
    };

    return Container(
      width: double.infinity,
      padding: AppSpace.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppRadius.xsAll,
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? fallback, size: 18, color: ink),
          AppSpace.gapW(AppSpace.sm),
          Expanded(
            child: Text(
              message,
              style: AppText.bodyS(color: AppColors.onStatusSurface),
            ),
          ),
        ],
      ),
    );
  }
}

enum AlertTone { info, warning, error, success }
