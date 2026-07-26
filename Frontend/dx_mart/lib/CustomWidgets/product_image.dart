import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/supabase.dart';
import '../design/app_colors.dart';

/// The one way this app draws a remote image.
///
/// Every image site used a raw `Image.network`, which means:
///   * **no disk cache** — `cached_network_image` was a declared dependency with zero
///     call sites, so the whole catalog was re-downloaded on every cold start. On a
///     metered 2G connection that is the single most expensive thing the app did.
///   * **no decode bounds** — a 1500px product photo was decoded at full resolution to
///     fill a 120dp thumbnail. Thirty of those resident at once is a real OOM risk on a
///     1 GB device, and the decode itself janks the scroll.
///   * **no placeholder on 10 of 13 sites** — the grid was blank white while bytes
///     arrived, which on 2G is most of the time the user is looking at it.
///
/// [path] is the STORED path (e.g. `uploads/x.png`) or an absolute URL; it is resolved
/// through [Db.imageUrl] either way.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.path,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.errorIcon,
  });

  final String? path;

  /// May be [double.infinity] for a full-bleed banner; the decode bound then falls back
  /// to the screen width.
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData? errorIcon;

  @override
  Widget build(BuildContext context) {
    final url = Db.imageUrl(path);
    final media = MediaQuery.maybeOf(context);
    final dpr = media?.devicePixelRatio ?? 2.0;

    // Decode at the size actually drawn (times the device pixel ratio, so it stays
    // sharp), not at whatever the source happens to be.
    final logicalWidth =
        width.isFinite ? width : (media?.size.width ?? 400);
    final cacheWidth = (logicalWidth * dpr).round().clamp(1, 2000);

    Widget image = url.isEmpty
        ? _empty(Icon(errorIcon ?? Icons.image_outlined,
            color: AppColors.iconMuted, size: 22))
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: cacheWidth,
            maxWidthDiskCache: cacheWidth,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => _loading(),
            errorWidget: (_, _, _) => _empty(
              Icon(errorIcon ?? Icons.broken_image_outlined,
                  color: AppColors.iconMuted, size: 22),
            ),
          );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  /// A visible block while bytes are in flight.
  ///
  /// This used to be `AppColors.backgroundColor` — pure `#FFFFFF` — painted on
  /// cards that are themselves white, so the "placeholder" was invisible and a
  /// loading grid rendered as genuinely empty space. The doc comment on it
  /// claimed "a quiet grey block ... so a loading grid reads as 'loading'
  /// instead of 'broken'", which is exactly what it did not do. On the
  /// connections this app is built for, that blank state is most of what the
  /// user actually looks at, so it is worth getting right.
  ///
  /// **Deliberately static, not shimmering.** It was a `Shimmer` briefly, and
  /// that hung the app: `Shimmer` drives a repeat-forever `AnimationController`
  /// per instance, and this widget is the image for every product card, every
  /// cart line and every category tile. A cart with a product rail below it put
  /// a dozen of them on screen at once, all invalidating every frame, and the
  /// emulator went to a 5.5-second frame and an ANR.
  ///
  /// Whole-screen skeletons still shimmer — see `AppSkeleton.sweep`, which
  /// wraps one animation around an entire arrangement rather than one per box,
  /// and only exists while a screen is genuinely empty.
  Widget _loading() => Container(
        width: width,
        height: height,
        color: AppColors.surfaceSunken,
      );

  /// No image, or the fetch failed. Static rather than shimmering — this state
  /// is final, and pulsing it would promise something still to come.
  Widget _empty(Widget child) => Container(
        width: width,
        height: height,
        color: AppColors.surfaceSunken,
        alignment: Alignment.center,
        child: child,
      );
}
