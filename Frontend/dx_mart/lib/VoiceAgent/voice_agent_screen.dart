import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_space.dart';
import '../design/app_type.dart';
import '../design/haptics.dart';
import 'audio/mic_capture.dart';
import 'models/voice_state.dart';
import 'widgets/mic_orb.dart';

/// Realtime voice ordering — "Ramu Bhai Live".
///
/// Pushed as its own full-screen route rather than added to the bottom nav:
/// the shell hardcodes its five tabs across four parallel lists and divides the
/// bar by `screenWidth / 5`, so a sixth entry means editing all of them. The
/// existing BolKeOrder tab is left exactly as it was.
///
/// Phase 1 scope: the page, the microphone, and the orb reacting to real
/// loudness. No network, no model, no speech yet.
class VoiceAgentScreen extends StatefulWidget {
  const VoiceAgentScreen({super.key});

  @override
  State<VoiceAgentScreen> createState() => _VoiceAgentScreenState();
}

class _VoiceAgentScreenState extends State<VoiceAgentScreen>
    with WidgetsBindingObserver {
  final MicCapture _mic = MicCapture();

  VoiceState _state = VoiceState.idle;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mic.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never leave a hot microphone behind when the app goes to the background.
    // A voice feature that keeps listening off-screen is the fastest way to
    // lose a user's trust permanently.
    if (state != AppLifecycleState.resumed && _mic.isCapturing) {
      _stop();
    }
  }

  Future<void> _toggle() async {
    if (_state.wantsMic) {
      await _stop();
      return;
    }

    setState(() {
      _state = VoiceState.connecting;
      _error = null;
    });

    final granted = await _mic.hasPermission();
    if (!mounted) return;

    if (!granted) {
      // Deliberately no deep-link into system settings: the package that
      // provides it (`permission_handler`) forces compileSdk 37, which this
      // project does not build against. Spelling out the path is worth less
      // than a button, but not worth dragging the whole app's Android SDK
      // forward for a beta feature.
      setState(() {
        _state = VoiceState.failed;
        _error = 'Mic ki permission chahiye. Phone Settings → Apps → '
            'DxMart → Permissions se mic on karein.';
      });
      AppHaptics.error();
      return;
    }

    try {
      await _mic.start();
      if (!mounted) return;
      AppHaptics.tap();
      setState(() => _state = VoiceState.listening);
    } catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      setState(() {
        _state = VoiceState.failed;
        _error = 'Mic shuru nahi ho paaya. Dobara koshish karein.';
      });
    }
  }

  Future<void> _stop() async {
    await _mic.stop();
    if (!mounted) return;
    AppHaptics.tap();
    setState(() => _state = VoiceState.idle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDarker,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surfaceDark,
              AppColors.surfaceDarker,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(onClose: () => Navigator.of(context).maybePop()),
              Expanded(child: _stage()),
              _BottomEscape(
                onBrowse: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MicOrb(
          state: _state,
          level: _mic.level,
          size: 232,
          onTap: _toggle,
        ),
        AppSpace.gapH(AppSpace.xxl),
        Text(
          _statusFor(_state),
          textAlign: TextAlign.center,
          style: AppText.h3(color: AppColors.onSurfaceDark),
        ),
        AppSpace.gapH(AppSpace.sm),
        Padding(
          padding: AppSpace.page,
          child: Text(
            _error ?? _hintFor(_state),
            textAlign: TextAlign.center,
            style: AppText.bodyS(color: AppColors.onSurfaceDarkMuted),
          ),
        ),
        AppSpace.gapH(AppSpace.xl),
        // Doubles as the Phase 1 proof that real audio is arriving, and as a
        // quiet signal to the user that they are actually being heard.
        SizedBox(
          height: AppSpace.h(36),
          child: _LevelTrail(level: _mic.level, active: _state.wantsMic),
        ),
        if (_state == VoiceState.failed) ...[
          AppSpace.gapH(AppSpace.lg),
          TextButton(
            onPressed: _toggle,
            child: Text(
              'Dobara koshish karein',
              style: AppText.button(color: AppColors.primaryBorder),
            ),
          ),
        ],
      ],
    );
  }

  static String _statusFor(VoiceState s) => switch (s) {
        VoiceState.idle => 'Boliye, main sun raha hoon',
        VoiceState.connecting => 'Ek second...',
        VoiceState.listening => 'Sun raha hoon...',
        VoiceState.thinking => 'Soch raha hoon...',
        VoiceState.speaking => 'Ramu Bhai bol rahe hain',
        VoiceState.confirming => 'Order confirm karein?',
        VoiceState.placing => 'Order ja raha hai...',
        VoiceState.placed => 'Order ho gaya!',
        VoiceState.failed => 'Ek dikkat aa gayi',
      };

  static String _hintFor(VoiceState s) => switch (s) {
        VoiceState.idle => 'Mic dabaakar boliye — jaise "do kilo aata".',
        VoiceState.listening => 'Rokne ke liye dobara tap karein.',
        _ => '',
      };
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpace.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: AppColors.onSurfaceDark),
            tooltip: 'Band karein',
          ),
          const Spacer(),
          Column(
            children: [
              Text('Ramu Bhai',
                  style: AppText.label(color: AppColors.onSurfaceDark)),
              // Being upfront that this is automated costs nothing in trust and
              // is the right default for a voice assistant.
              Text('AI assistant',
                  style: AppText.overline(
                      color: AppColors.onSurfaceDarkMuted)),
            ],
          ),
          const Spacer(),
          Container(
            margin: EdgeInsets.only(right: AppSpace.w(AppSpace.sm)),
            padding: AppSpace.symmetric(
                horizontal: AppSpace.sm, vertical: AppSpace.xs),
            decoration: BoxDecoration(
              color: AppColors.discountSurface.withValues(alpha: 0.16),
              borderRadius: AppRadius.pillAll,
            ),
            child: Text('BETA',
                style: AppText.overline(color: AppColors.discount)),
          ),
        ],
      ),
    );
  }
}

/// The always-available way out.
///
/// A voice feature must never be the only path to an order — if recognition
/// fails, or the room is loud, or the user simply cannot speak right now, the
/// normal shop is one tap away.
class _BottomEscape extends StatelessWidget {
  const _BottomEscape({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpace.symmetric(
          horizontal: AppSpace.gutter, vertical: AppSpace.base),
      child: TextButton.icon(
        onPressed: onBrowse,
        icon: Icon(Icons.grid_view_rounded,
            size: 18.sp, color: AppColors.onSurfaceDarkMuted),
        label: Text(
          'Bina bole order karein',
          style: AppText.bodyS(color: AppColors.onSurfaceDarkMuted),
        ),
      ),
    );
  }
}

/// A short rolling history of loudness, drawn as bars.
class _LevelTrail extends StatefulWidget {
  const _LevelTrail({required this.level, required this.active});

  final ValueListenable<double> level;
  final bool active;

  @override
  State<_LevelTrail> createState() => _LevelTrailState();
}

class _LevelTrailState extends State<_LevelTrail> {
  static const int _bars = 32;
  final List<double> _history = List<double>.filled(_bars, 0);

  @override
  void initState() {
    super.initState();
    widget.level.addListener(_push);
  }

  @override
  void dispose() {
    widget.level.removeListener(_push);
    super.dispose();
  }

  void _push() {
    if (!mounted) return;
    setState(() {
      _history.removeAt(0);
      _history.add(widget.level.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(AppSpace.w(220), AppSpace.h(36)),
      painter: _TrailPainter(
        history: _history,
        color: widget.active
            ? AppColors.primaryBorder
            : AppColors.onSurfaceDarkMuted.withValues(alpha: 0.35),
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.history, required this.color});

  final List<double> history;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;
    final slot = size.width / history.length;
    final w = slot * 0.42;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;

    for (var i = 0; i < history.length; i++) {
      final v = history[i].clamp(0.0, 1.0);
      // A floor so the trail reads as a resting line rather than vanishing.
      final h = math.max(size.height * 0.06, size.height * v);
      final x = slot * i + slot / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => true;
}
