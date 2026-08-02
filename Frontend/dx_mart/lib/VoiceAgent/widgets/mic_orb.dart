import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../design/app_colors.dart';
import '../models/voice_state.dart';

/// The single living thing on the voice screen.
///
/// A spinner would say "wait"; this says "I am listening to you". The blob is
/// drawn from a couple of sine harmonics rather than assembled from Lottie or
/// a shader so it costs one [CustomPainter] and no new dependency, and so its
/// motion can be driven directly by real microphone loudness.
///
/// [level] is whatever the screen decides is the current energy — microphone
/// RMS while listening, and (from Phase 4) the agent's output envelope while
/// speaking. Keeping it as one input means the orb never needs to know which
/// half of the conversation is talking.
class MicOrb extends StatefulWidget {
  const MicOrb({
    super.key,
    required this.state,
    required this.level,
    this.size = 220,
    this.onTap,
  });

  final VoiceState state;
  final ValueListenable<double> level;
  final double size;
  final VoidCallback? onTap;

  @override
  State<MicOrb> createState() => _MicOrbState();
}

class _MicOrbState extends State<MicOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _OrbPalette.of(widget.state);
    final d = widget.size.w;

    return Semantics(
      button: widget.onTap != null,
      label: _semanticLabel(widget.state),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: d,
          height: d,
          child: AnimatedBuilder(
            animation: Listenable.merge([_phase, widget.level]),
            builder: (context, _) {
              return CustomPaint(
                painter: _OrbPainter(
                  t: _phase.value * 2 * math.pi,
                  level: widget.level.value.clamp(0.0, 1.0),
                  palette: palette,
                  state: widget.state,
                ),
                child: Center(
                  child: Icon(
                    _glyph(widget.state),
                    size: (d * 0.22),
                    color: palette.glyph,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static IconData _glyph(VoiceState s) => switch (s) {
        VoiceState.idle => Icons.mic_none_rounded,
        VoiceState.connecting => Icons.more_horiz_rounded,
        VoiceState.listening => Icons.mic_rounded,
        VoiceState.thinking => Icons.auto_awesome_rounded,
        VoiceState.speaking => Icons.graphic_eq_rounded,
        VoiceState.confirming => Icons.receipt_long_rounded,
        VoiceState.placing => Icons.hourglass_top_rounded,
        VoiceState.placed => Icons.check_rounded,
        VoiceState.failed => Icons.priority_high_rounded,
      };

  static String _semanticLabel(VoiceState s) => switch (s) {
        VoiceState.idle => 'Start voice ordering',
        VoiceState.listening => 'Listening. Tap to stop',
        VoiceState.speaking => 'Assistant is speaking. Tap to interrupt',
        _ => 'Voice ordering',
      };
}

/// Colours for one state, resolved from the app palette rather than invented.
class _OrbPalette {
  const _OrbPalette({
    required this.core,
    required this.halo,
    required this.glyph,
  });

  final Color core;
  final Color halo;
  final Color glyph;

  factory _OrbPalette.of(VoiceState s) => switch (s) {
        VoiceState.idle => _OrbPalette(
            core: AppColors.secondary,
            halo: AppColors.onSurfaceDarkMuted,
            glyph: AppColors.onSurfaceDarkMuted,
          ),
        VoiceState.connecting => _OrbPalette(
            core: AppColors.secondary,
            halo: AppColors.secondaryBorder,
            glyph: AppColors.onSurfaceDark,
          ),
        VoiceState.listening => _OrbPalette(
            core: AppColors.primary,
            halo: AppColors.primaryBorder,
            glyph: AppColors.onPrimary,
          ),
        VoiceState.thinking => _OrbPalette(
            core: AppColors.info,
            halo: AppColors.infoBorder,
            glyph: AppColors.onSurfaceDark,
          ),
        VoiceState.speaking => _OrbPalette(
            core: AppColors.discount,
            halo: AppColors.discountBorder,
            glyph: AppColors.onDiscount,
          ),
        VoiceState.confirming || VoiceState.placing => _OrbPalette(
            core: AppColors.primary,
            halo: AppColors.primaryBorder,
            glyph: AppColors.onPrimary,
          ),
        VoiceState.placed => _OrbPalette(
            core: AppColors.success,
            halo: AppColors.successBorder,
            glyph: AppColors.onPrimary,
          ),
        VoiceState.failed => _OrbPalette(
            core: AppColors.danger,
            halo: AppColors.dangerBorder,
            glyph: AppColors.onPrimary,
          ),
      };
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.t,
    required this.level,
    required this.palette,
    required this.state,
  });

  final double t;
  final double level;
  final _OrbPalette palette;
  final VoiceState state;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // How far the outline departs from a circle, and how fast it travels.
    // Idle barely moves; listening tracks the voice; thinking churns on its
    // own because there is no external energy to track.
    final (wobble, speed) = switch (state) {
      VoiceState.idle => (0.020 + 0.010 * math.sin(t * 0.5), 0.5),
      VoiceState.connecting => (0.035, 1.4),
      VoiceState.listening => (0.028 + level * 0.170, 1.1),
      VoiceState.thinking => (0.060, 1.9),
      VoiceState.speaking => (0.035 + level * 0.110, 1.5),
      VoiceState.confirming => (0.030, 0.8),
      VoiceState.placing => (0.050, 1.9),
      VoiceState.placed => (0.020, 0.4),
      VoiceState.failed => (0.025, 0.6),
    };

    final tt = t * speed;

    // Loudness swells the whole orb a little, so it reads as breathing rather
    // than merely rippling at a fixed size.
    final base = r * (0.56 + level * 0.10);

    // Halo — a wide, very soft bloom that makes the orb sit in the dark canvas
    // instead of on top of it.
    canvas.drawCircle(
      c,
      base * 1.85,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.halo.withValues(alpha: 0.22 + level * 0.20),
            palette.halo.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: base * 1.85)),
    );

    // Two offset rings, then the solid core. Different lobe counts and phase
    // directions stop them moving as one rigid shape.
    _drawBlob(canvas, c, base * 1.34, tt * 0.8, wobble * 1.25, 3,
        Paint()..color = palette.halo.withValues(alpha: 0.16));
    _drawBlob(canvas, c, base * 1.15, -tt * 1.1, wobble, 4,
        Paint()..color = palette.halo.withValues(alpha: 0.28));

    _drawBlob(
      canvas,
      c,
      base,
      tt,
      wobble * 0.75,
      5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(palette.core, palette.halo, 0.35)!,
            palette.core,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: base * 1.2)),
    );
  }

  /// A closed blob: a circle whose radius is modulated by two harmonics, so the
  /// silhouette moves organically instead of pulsing as a perfect ring.
  void _drawBlob(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    double wobble,
    int lobes,
    Paint paint,
  ) {
    const steps = 96;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final a = (i / steps) * 2 * math.pi;
      final d = 1 +
          wobble * math.sin(lobes * a + t) * 0.6 +
          wobble * math.sin((lobes + 2) * a - t * 1.3) * 0.4;
      final rr = r * d;
      final p = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t ||
      old.level != level ||
      old.state != state ||
      old.palette.core != palette.core;
}
