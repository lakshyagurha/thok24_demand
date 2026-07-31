import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';

/// One screen header.
///
/// The app hand-rolled seven of these and used no `AppBar` anywhere, with
/// **five different status-bar strategies**: a white `Container` of
/// `padding.top`, a transparent `SizedBox` of `padding.top + 10`, a white one
/// at `padding.top` with a 56dp bar, a **fixed `17.h`** that ignored the notch
/// entirely, and — on Profile — no header at all, just `top: 50.h`.
///
/// The back affordance came in two incompatible designs too: a 30x30 circle
/// tinted with the primary, and a 25x28 solid-green rounded rectangle holding a
/// black `arrow_back_ios` nudged sideways with `EdgeInsets.only(left: 7.w)` to
/// fake optical centring.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.showBack = true,
    this.background,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool showBack;
  final Color? background;

  @override
  Size get preferredSize => Size.fromHeight(AppSpace.headerHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background ?? AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSpace.h(AppSpace.headerHeight),
          child: Padding(
            padding: AppSpace.symmetric(horizontal: AppSpace.md),
            child: Row(
              children: [
                if (showBack)
                  _CircleAction(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack ?? () => Navigator.maybePop(context),
                  ),
                if (showBack) AppSpace.gapW(AppSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.h2(),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(),
                        ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button with a real 44dp target.
class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: AppSpace.w(24),
      child: SizedBox(
        width: AppSpace.w(AppSpace.minTapTarget),
        height: AppSpace.w(AppSpace.minTapTarget),
        child: Center(
          child: Container(
            width: AppSpace.w(34),
            height: AppSpace.w(34),
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

/// The same round back affordance [AppHeader] uses, for the ~10 screens that
/// build their own header row instead of using [AppHeader] outright. Every
/// one of them had copy-pasted a 25x28 solid-green rounded rectangle holding
/// a black `arrow_back_ios` — a ~3.2:1 contrast pairing nudged sideways with
/// `EdgeInsets.only(left: 7.w)` to fake optical centring. This is that same
/// light-surface circle with a real 44dp tap target instead.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _CircleAction(
      icon: Icons.arrow_back_rounded,
      onTap: onTap ?? () => Navigator.maybePop(context),
    );
  }
}

/// A header action: an icon with an optional count badge.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: AppSpace.w(24),
      child: SizedBox(
        width: AppSpace.w(AppSpace.minTapTarget),
        height: AppSpace.w(AppSpace.minTapTarget),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: AppColors.icon),
            if (badgeCount != null && badgeCount! > 0)
              Positioned(
                top: AppSpace.h(6),
                right: AppSpace.w(4),
                child: Container(
                  padding: AppSpace.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: AppText.overline(color: AppColors.textInverse),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
