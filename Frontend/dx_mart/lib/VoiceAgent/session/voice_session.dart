import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../CustomWidgets/cart_provider.dart';
import '../../core/supabase.dart';
import '../../design/haptics.dart';
import '../models/voice_state.dart';
import '../tools/tool_dispatcher.dart';
import 'rpc_handlers.dart';

/// One line of the conversation ribbon.
class VoiceTurn {
  VoiceTurn({required this.fromUser, required this.text, required this.id});
  final bool fromUser;
  final String id;
  String text;
}

/// Orchestrates one voice ordering session over LiveKit.
///
/// Replaces a hand-rolled PCM-over-WebSocket stack that failed on real
/// hardware: without a `VOICE_COMMUNICATION` audio route there was no working
/// acoustic echo cancellation, so the agent heard itself and interrupted its
/// own reply about 100ms in, every time. WebRTC gives correct audio routing,
/// an adaptive jitter buffer and packet-loss concealment, none of which is
/// worth reimplementing.
///
/// Scoped to the route, not the app, so the room, the microphone and the audio
/// device are all released when the page is popped.
class VoiceSession extends ChangeNotifier {
  VoiceSession({required CartProvider cart}) {
    _tools = ToolDispatcher(cart: cart, onCardsChanged: _onToolsChanged);
  }

  late final ToolDispatcher _tools;

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  Timer? _levelTicker;
  Timer? _idle;
  bool _disposed = false;
  String? _agentIdentity;

  VoiceState _state = VoiceState.idle;
  String? _error;

  final List<VoiceTurn> turns = [];

  /// 0..1 energy for the orb: the agent's voice while it speaks, ours otherwise.
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  VoiceState get state => _state;
  String? get error => _error;
  List<VoiceCard> get cards => _tools.cards;
  bool get ordered => _tools.ordered;

  /// A phone left face-down must not hold a billed agent session open.
  static const Duration _idleTimeout = Duration(minutes: 2);

  // ---------------------------------------------------------------------------

  /// Warms DNS, TLS and ICE while the user is still looking at the screen, so
  /// the tap itself is not paying for connection setup.
  Future<void> warmUp() async {
    if (_room != null || !Db.isSignedIn) return;
    try {
      final cfg = await _fetchToken();
      final room = Room();
      await room.prepareConnection(cfg.url, cfg.token);
      // Deliberately not retained: the token is short-lived and start() fetches
      // a fresh one. This call exists only for its DNS/TLS/ICE side effects.
      await room.dispose();
    } catch (_) {
      // Warm-up is best-effort. A failure here must not surface to the user.
    }
  }

  Future<void> start() async {
    if (_state.isLive) return;
    _set(VoiceState.connecting, error: null);

    if (!Db.isSignedIn) {
      _fail('Voice ordering ke liye sign in karna hoga.');
      return;
    }

    try {
      final cfg = await _fetchToken();

      final room = Room(
        roomOptions: const RoomOptions(
          // Software AEC/NS/AGC on top of whatever the device provides. This is
          // the fix for the self-interruption loop.
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
        ),
      );
      _room = room;

      // Before connect: the agent may issue its first tool call the instant it
      // joins, and a handler registered afterwards would miss it.
      registerVoiceRpc(room, _tools);

      _listener = room.createListener();
      _wireEvents(_listener!);

      await room.connect(cfg.url, cfg.token);
      await room.localParticipant?.setMicrophoneEnabled(true);

      AppHaptics.tap();
      _set(VoiceState.listening);
      _startLevelTicker();
      _armIdle();
    } on DataException catch (e) {
      _fail(e.message);
    } catch (e) {
      debugPrint('VoiceSession.start failed: $e');
      _fail('Voice shuru nahi ho paaya. Dobara koshish karein.');
    }
  }

  Future<void> stop() async {
    _idle?.cancel();
    _levelTicker?.cancel();
    _levelTicker = null;
    await _listener?.dispose();
    _listener = null;
    final room = _room;
    _room = null;
    _agentIdentity = null;
    level.value = 0;
    try {
      await room?.disconnect();
      await room?.dispose();
    } catch (_) {
      // Already torn down.
    }
    if (!_disposed && _state != VoiceState.placed) _set(VoiceState.idle);
  }

  /// The typed fallback. Voice must never be the only way through.
  Future<void> sendText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    // Typing before the session is open used to be a silent no-op. Start one.
    if (_room == null) {
      await start();
      if (_room == null) return;
    }

    turns.add(VoiceTurn(fromUser: true, text: t, id: 'typed-${turns.length}'));
    notifyListeners();
    _armIdle();
    try {
      await _room!.localParticipant?.sendText(
        t,
        options: SendTextOptions(topic: 'lk.chat'),
      );
    } catch (e) {
      debugPrint('sendText failed: $e');
    }
  }

  // ---------------------------------------------------------------------------

  void _wireEvents(EventsListener<RoomEvent> l) {
    // The agent's own state, published by LiveKit as a participant attribute.
    l.on<ParticipantAttributesChanged>((e) {
      if (e.participant is! RemoteParticipant) return;
      _agentIdentity = e.participant.identity;
      final s = e.attributes['lk.agent.state'];
      if (s == null) return;
      // confirming / placing / placed are ours, not LiveKit's — it cannot know
      // that a cart has been read back or an order is in flight.
      if (_state == VoiceState.confirming ||
          _state == VoiceState.placing ||
          _state == VoiceState.placed) {
        return;
      }
      switch (s) {
        case 'initializing':
          _set(VoiceState.connecting);
        case 'listening':
          _set(VoiceState.listening);
        case 'thinking':
          _set(VoiceState.thinking);
        case 'speaking':
          _set(VoiceState.speaking);
      }
    });

    l.on<ParticipantConnectedEvent>((e) {
      _agentIdentity ??= e.participant.identity;
    });

    l.on<TranscriptionEvent>((e) {
      final fromUser = e.participant.identity == _room?.localParticipant?.identity;
      for (final seg in e.segments) {
        _upsertTurn(id: seg.id, fromUser: fromUser, text: seg.text);
      }
      _armIdle();
      notifyListeners();
    });

    l.on<RoomDisconnectedEvent>((e) {
      if (_disposed) return;
      if (_state == VoiceState.placed) return;
      debugPrint('room disconnected: ${e.reason}');
      _fail('Connection टूट गया. Dobara shuru karein.');
    });
  }

  /// Transcription arrives as revisions of the same segment id, so replace in
  /// place rather than appending a line per fragment.
  void _upsertTurn({
    required String id,
    required bool fromUser,
    required String text,
  }) {
    if (text.isEmpty) return;
    for (final t in turns) {
      if (t.id == id) {
        t.text = text;
        return;
      }
    }
    turns.add(VoiceTurn(fromUser: fromUser, text: text, id: id));
    if (turns.length > 40) turns.removeRange(0, turns.length - 40);
  }

  void _onToolsChanged() {
    if (_disposed) return;
    // Local states the agent cannot report.
    if (_tools.ordered) {
      _set(VoiceState.placed);
      AppHaptics.success();
    }
    notifyListeners();
  }

  void _startLevelTicker() {
    _levelTicker?.cancel();
    _levelTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final room = _room;
      if (room == null) return;
      double v = 0;
      if (_state == VoiceState.speaking && _agentIdentity != null) {
        v = room.remoteParticipants[_agentIdentity]?.audioLevel ?? 0;
      } else {
        v = room.localParticipant?.audioLevel ?? 0;
      }
      // audioLevel is already 0..1; a little gain makes quiet speech visible.
      level.value = (v * 3.0).clamp(0.0, 1.0);
    });
  }

  void _armIdle() {
    _idle?.cancel();
    _idle = Timer(_idleTimeout, () {
      if (_state.isLive) unawaited(stop());
    });
  }

  Future<_VoiceConnectConfig> _fetchToken() async {
    try {
      final res = await Db.client.functions.invoke('voice-token');
      final data = res.data;
      if (data is! Map || data['token'] == null || data['url'] == null) {
        throw DataException('Voice ordering is unavailable right now.');
      }
      return _VoiceConnectConfig(
        url: data['url'] as String,
        token: data['token'] as String,
      );
    } on DataException {
      rethrow;
    } catch (e) {
      rethrowFunctionError(e, 'Voice ordering is unavailable right now.');
    }
  }

  void _fail(String message) {
    _error = message;
    _set(VoiceState.failed);
    AppHaptics.error();
    unawaited(stop());
  }

  void _set(VoiceState s, {String? error}) {
    if (_disposed) return;
    _state = s;
    if (error != null || s != VoiceState.failed) _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _idle?.cancel();
    _levelTicker?.cancel();
    unawaited(_listener?.dispose());
    final room = _room;
    _room = null;
    unawaited(() async {
      try {
        await room?.disconnect();
        await room?.dispose();
      } catch (_) {}
    }());
    level.dispose();
    super.dispose();
  }
}

class _VoiceConnectConfig {
  const _VoiceConnectConfig({required this.url, required this.token});
  final String url;
  final String token;
}
