import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../CustomWidgets/cart_provider.dart';
import '../CustomWidgets/product_image.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_space.dart';
import '../design/app_type.dart';
import 'models/voice_state.dart';
import 'session/voice_session.dart';
import 'tools/tool_dispatcher.dart' show VoiceCard;
import 'widgets/mic_orb.dart';

/// Realtime voice ordering — "Ramu Bhai Live".
///
/// A full-screen route rather than a sixth bottom-nav tab: the shell hardcodes
/// its five tabs across four parallel lists and divides the bar by
/// `screenWidth / 5`, so adding one means editing all of them.
class VoiceAgentScreen extends StatelessWidget {
  const VoiceAgentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Scoped to this route, not to main.dart, so the socket, the microphone and
    // the audio device are all released when the page is popped.
    return ChangeNotifierProvider<VoiceSession>(
      create: (_) => VoiceSession(cart: context.read<CartProvider>()),
      child: const _VoiceAgentView(),
    );
  }
}

class _VoiceAgentView extends StatefulWidget {
  const _VoiceAgentView();

  @override
  State<_VoiceAgentView> createState() => _VoiceAgentViewState();
}

class _VoiceAgentViewState extends State<_VoiceAgentView>
    with WidgetsBindingObserver {
  final TextEditingController _text = TextEditingController();
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Warm DNS, TLS and ICE while the user is still reading the screen, so the
    // tap itself is not paying for connection setup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<VoiceSession>().warmUp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never leave a hot microphone behind. A voice feature that keeps listening
    // off-screen loses a user's trust exactly once.
    if (state != AppLifecycleState.resumed) {
      context.read<VoiceSession>().stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<VoiceSession>();

    return Scaffold(
      backgroundColor: AppColors.surfaceDarker,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceDark, AppColors.surfaceDarker],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(onClose: () => Navigator.of(context).maybePop()),
              Expanded(
                child: SingleChildScrollView(
                  reverse: true,
                  padding: AppSpace.symmetric(vertical: AppSpace.base),
                  child: Column(
                    children: [
                      MicOrb(
                        state: session.state,
                        level: session.level,
                        size: 190,
                        onTap: () => session.state.isLive
                            ? session.stop()
                            : session.start(),
                      ),
                      AppSpace.gapH(AppSpace.lg),
                      Text(
                        _statusFor(session.state),
                        textAlign: TextAlign.center,
                        style: AppText.h3(color: AppColors.onSurfaceDark),
                      ),
                      if (session.error != null) ...[
                        AppSpace.gapH(AppSpace.sm),
                        Padding(
                          padding: AppSpace.page,
                          child: Text(
                            session.error!,
                            textAlign: TextAlign.center,
                            style: AppText.bodyS(color: AppColors.dangerBorder),
                          ),
                        ),
                      ] else if (session.state == VoiceState.idle) ...[
                        AppSpace.gapH(AppSpace.sm),
                        Padding(
                          padding: AppSpace.page,
                          child: Text(
                            'Mic dabaakar boliye — jaise "do kilo aata".',
                            textAlign: TextAlign.center,
                            style: AppText.bodyS(
                                color: AppColors.onSurfaceDarkMuted),
                          ),
                        ),
                      ],
                      AppSpace.gapH(AppSpace.lg),
                      _Transcript(turns: session.turns),
                      if (session.cards.isNotEmpty) ...[
                        AppSpace.gapH(AppSpace.base),
                        _Cards(cards: session.cards),
                      ],
                    ],
                  ),
                ),
              ),
              _Footer(
                typing: _typing,
                controller: _text,
                onToggleTyping: () => setState(() => _typing = !_typing),
                onSubmit: (v) {
                  session.sendText(v);
                  _text.clear();
                },
                onBrowse: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusFor(VoiceState s) => switch (s) {
        VoiceState.idle => 'Boliye, main sun raha hoon',
        VoiceState.connecting => 'Jud raha hoon...',
        VoiceState.listening => 'Sun raha hoon...',
        VoiceState.thinking => 'Soch raha hoon...',
        VoiceState.speaking => 'Ramu Bhai bol rahe hain',
        VoiceState.confirming => 'Order confirm karein?',
        VoiceState.placing => 'Order ja raha hai...',
        VoiceState.placed => 'Order ho gaya!',
        VoiceState.failed => 'Ek dikkat aa gayi',
      };
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          AppSpace.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
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
              // Being upfront that this is automated costs nothing in trust.
              Text('AI assistant',
                  style:
                      AppText.overline(color: AppColors.onSurfaceDarkMuted)),
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
            child:
                Text('BETA', style: AppText.overline(color: AppColors.discount)),
          ),
        ],
      ),
    );
  }
}

/// The conversation, as a ribbon rather than a chat log.
class _Transcript extends StatelessWidget {
  const _Transcript({required this.turns});
  final List<VoiceTurn> turns;

  @override
  Widget build(BuildContext context) {
    if (turns.isEmpty) return const SizedBox.shrink();
    final recent = turns.length > 6 ? turns.sublist(turns.length - 6) : turns;

    return Padding(
      padding: AppSpace.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < recent.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpace.h(AppSpace.sm)),
              child: Align(
                alignment: recent[i].fromUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Opacity(
                  // Older lines recede instead of scrolling away, so the eye
                  // stays on what was just said.
                  opacity: 0.35 + 0.65 * ((i + 1) / recent.length),
                  child: Text(
                    recent[i].text,
                    textAlign:
                        recent[i].fromUser ? TextAlign.right : TextAlign.left,
                    style: recent[i].fromUser
                        ? AppText.bodyS(color: AppColors.onSurfaceDarkMuted)
                        : AppText.bodyL(color: AppColors.onSurfaceDark),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Products the agent has actually added — one card per confirmed tool call.
class _Cards extends StatelessWidget {
  const _Cards({required this.cards});
  final List<VoiceCard> cards;

  @override
  Widget build(BuildContext context) {
    final total = cards.fold<double>(0, (s, c) => s + c.lineTotal);
    return Padding(
      padding: AppSpace.page,
      child: Column(
        children: [
          for (final c in cards)
            Container(
              margin: EdgeInsets.only(bottom: AppSpace.h(AppSpace.sm)),
              padding: AppSpace.cardCompact,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceDark.withValues(alpha: 0.06),
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: AppColors.onSurfaceDark.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.smAll,
                    child: Container(
                      color: Colors.white,
                      child: ProductImage(
                        path: c.imagePath,
                        width: 44.w,
                        height: 44.w,
                      ),
                    ),
                  ),
                  AppSpace.gapW(AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyS(
                                color: AppColors.onSurfaceDark)),
                        Text('${c.variantName} × ${c.quantity}',
                            style: AppText.caption(
                                color: AppColors.onSurfaceDarkMuted)),
                      ],
                    ),
                  ),
                  Text('₹${c.lineTotal.toStringAsFixed(0)}',
                      style: AppText.priceM(color: AppColors.onSurfaceDark)),
                ],
              ),
            ),
          AppSpace.gapH(AppSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${cards.length} saman',
                  style: AppText.label(color: AppColors.onSurfaceDarkMuted)),
              Text('₹${total.toStringAsFixed(0)}',
                  style: AppText.priceL(color: AppColors.primaryBorder)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The escape hatches. Voice must never be the only way through: if
/// recognition fails, the room is loud, or the user simply cannot speak right
/// now, typing and the ordinary shop are both one tap away.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.typing,
    required this.controller,
    required this.onToggleTyping,
    required this.onSubmit,
    required this.onBrowse,
  });

  final bool typing;
  final TextEditingController controller;
  final VoidCallback onToggleTyping;
  final ValueChanged<String> onSubmit;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpace.symmetric(
          horizontal: AppSpace.gutter, vertical: AppSpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (typing)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpace.h(AppSpace.sm)),
              child: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.send,
                onSubmitted: onSubmit,
                style: AppText.bodyM(color: AppColors.onSurfaceDark),
                decoration: InputDecoration(
                  hintText: 'Likhiye... jaise "do kilo aata"',
                  hintStyle:
                      AppText.bodyS(color: AppColors.onSurfaceDarkMuted),
                  filled: true,
                  fillColor: AppColors.onSurfaceDark.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.pillAll,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: AppSpace.symmetric(
                      horizontal: AppSpace.base, vertical: AppSpace.md),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send_rounded,
                        color: AppColors.primaryBorder, size: 20.sp),
                    onPressed: () => onSubmit(controller.text),
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: onToggleTyping,
                icon: Icon(typing ? Icons.mic_rounded : Icons.keyboard_rounded,
                    size: 18.sp, color: AppColors.onSurfaceDarkMuted),
                label: Text(typing ? 'Bolein' : 'Likhein',
                    style:
                        AppText.bodyS(color: AppColors.onSurfaceDarkMuted)),
              ),
              TextButton.icon(
                onPressed: onBrowse,
                icon: Icon(Icons.grid_view_rounded,
                    size: 18.sp, color: AppColors.onSurfaceDarkMuted),
                label: Text('Saman dikhao',
                    style:
                        AppText.bodyS(color: AppColors.onSurfaceDarkMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
