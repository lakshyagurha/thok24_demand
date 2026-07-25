import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/supabase.dart';
import '../utils/colors.dart';

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
        ? _placeholder(Icon(errorIcon ?? Icons.image_outlined, color: Colors.grey))
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: cacheWidth,
            maxWidthDiskCache: cacheWidth,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, __) => _placeholder(null),
            errorWidget: (_, __, ___) => _placeholder(
              Icon(errorIcon ?? Icons.broken_image_outlined, color: Colors.grey),
            ),
          );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  /// A quiet grey block rather than empty space, so a loading grid reads as "loading"
  /// instead of "broken".
  Widget _placeholder(Widget? child) => Container(
        width: width,
        height: height,
        color: AppColors.backgroundColor,
        alignment: Alignment.center,
        child: child,
      );
}
