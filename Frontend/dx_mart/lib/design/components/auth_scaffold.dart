import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_gradients.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';
import 'brand_lockup.dart';

/// The shell every auth screen sits in.
///
/// Login, signup, OTP and email sign-in were four separate ad-hoc columns —
/// different top offsets (80h vs 60h vs 40h), the logo at three different
/// sizes, gutters of 20w on some and 16w on others, and no shared idea of where
/// a title goes. They are the first thing a new user ever sees, and they did not
/// look like the same product as each other, let alone as the app.
///
/// The layout: a brand band that fades into the page, a title and a supporting
/// line, then a white card holding the form. The card matters — it gives the
/// inputs a surface to sit on, which is what makes a form feel like a discrete
/// task rather than text floating on a screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showBack = true,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;

  /// Sits below the card, outside it — "Don't have an account?" and similar.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.heroSoft),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBack)
                Padding(
                  padding: AppSpace.symmetric(horizontal: AppSpace.sm),
                  child: InkResponse(
                    onTap: () => Navigator.maybePop(context),
                    radius: AppSpace.w(24),
                    child: SizedBox(
                      width: AppSpace.w(AppSpace.minTapTarget),
                      height: AppSpace.w(AppSpace.minTapTarget),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
              else
                AppSpace.gapH(AppSpace.sm),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.w(AppSpace.lg),
                    AppSpace.h(AppSpace.sm),
                    AppSpace.w(AppSpace.lg),
                    AppSpace.h(AppSpace.xl),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandLockup(size: BrandLockupSize.md),
                      AppSpace.gapH(AppSpace.xl),
                      Text(title, style: AppText.h1()),
                      if (subtitle != null) ...[
                        AppSpace.gapH(AppSpace.xs),
                        Text(
                          subtitle!,
                          style: AppText.bodyM(color: AppColors.textSecondary),
                        ),
                      ],
                      AppSpace.gapH(AppSpace.lg),
                      Container(
                        width: double.infinity,
                        padding: AppSpace.all(AppSpace.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.lgAll,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: child,
                      ),
                      if (footer != null) ...[
                        AppSpace.gapH(AppSpace.lg),
                        Center(child: footer!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
