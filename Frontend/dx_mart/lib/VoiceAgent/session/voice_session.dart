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
  VoiceTurn({
    required this.fromUser,
    required this.text,
    required this.id,
    this.isFinal = false,
  });
  final bool fromUser;
  String id;
  String text;
  bool isFinal;
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
  bool _micOpen = false;
  String? _agentIdentity;

  VoiceState _state = VoiceState.idle;
  String? _error;

  /// Last raw disconnect reason, for diagnosis. Not shown to the customer.
  String? lastDisconnectReason;

  final List<VoiceTurn> turns = [];

  /// 0..1 energy for the orb: the agent's voice while it speaks, ours otherwise.
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  VoiceState get state => _state;
  String? get error => _error;
  List<VoiceCard> get cards => _tools.cards;
  bool get ordered => _tools.ordered;

  /// Adjusts a line from the card's own +/- control.
  Future<void> nudgeCard(VoiceCard card, int delta) => _tools.nudge(card, delta);

  /// A phone left face-down must not hold a billed agent session open.
  static const Duration _idleTimeout = Duration(minutes: 2);

  static bool _audioConfigured = false;

  /// Puts Android into communication audio mode before WebRTC starts.
  ///
  /// This is the fix for the agent hearing itself. Android's hardware acoustic
  /// echo canceller only engages when the audio session is in
  /// `inCommunication` mode with voice-communication usage; left on the default
  /// media route, the speaker feeds straight back into the microphone, the
  /// model's VAD reads that as the customer interrupting, and the agent cuts
  /// itself off mid-sentence.
  ///
  /// It must run BEFORE WebRTC initialises — the SDK reads these attributes
  /// when it builds the audio device module, and setting them afterwards is
  /// silently too late. Idempotent, because a second call after WebRTC is up
  /// would do nothing useful.
  static Future<void> _configureAudioSession() async {
    if (_audioConfigured) return;
    _audioConfigured = true;
    try {
      await LiveKitClient.initialize(
        initialAudioSessionOptions: const AudioSessionOptions.communication(),
      );
      // Grocery ordering happens with the phone in your hand, not at your ear.
      await AudioManager.instance.setSpeakerOutputPreferred(true);
    } catch (e) {
      debugPrint('audio session setup failed: $e');
    }
  }

  // ---------------------------------------------------------------------------

  /// Warms DNS, TLS and ICE while the user is still looking at the screen, so
  /// the tap itself is not paying for connection setup.
  Future<void> warmUp() async {
    if (_room != null || !Db.isSignedIn) return;
    // Done here rather than at connect time so it lands well before WebRTC is
    // first touched, which is the only point at which it takes effect.
    await _configureAudioSession();
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
      // Safety net: if the screen was opened faster than warmUp() ran, this is
      // still ahead of the first Room().
      await _configureAudioSession();
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
      _registerTranscriptStream(room);

      _listener = room.createListener();
      _wireEvents(_listener!);

      await room.connect(cfg.url, cfg.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      // Keep the flag in step with reality. Enabling the track here without
      // recording it left _setMicOpen believing the microphone was shut, so its
      // idempotence guard skipped the calls that were meant to reopen it and
      // the session went permanently deaf after the agent's first sentence.
      _micOpen = true;

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

  /// Subscribes to the transcript.
  ///
  /// Transcripts do NOT arrive as `TranscriptionEvent` here — the agent
  /// publishes them as a text stream on `lk.transcription`, and without a
  /// handler the SDK logs "ignoring incoming text stream due to no handler for
  /// topic lk.transcription" and drops them on the floor. That is why the
  /// screen stayed blank while the agent was talking.
  ///
  /// Must be registered before connect, for the same reason as the RPC methods.
  void _registerTranscriptStream(Room room) {
    room.registerTextStreamHandler('lk.transcription', (reader, identity) async {
      try {
        final attrs = reader.info?.attributes ?? const <String, String>{};
        // A segment id is stable across revisions of the same utterance, so it
        // is what keeps a growing sentence on one line instead of spraying a
        // new line per fragment.
        final segmentId =
            attrs['lk.segment_id'] ?? reader.info?.id ?? 'seg-${turns.length}';
        final finalFlag = attrs['lk.transcription_final'];
        final text = await reader.readAll();
        if (_disposed) return;

        _upsertTurn(
          id: segmentId,
          fromUser: identity == _room?.localParticipant?.identity,
          text: text,
          isFinal: finalFlag == 'true' || finalFlag == '1',
        );
        _armIdle();
        notifyListeners();
      } catch (e) {
        debugPrint('[VoiceAgent] transcript stream failed: $e');
      }
    });
  }

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
          _setMicOpen(true);
          _set(VoiceState.listening);
        case 'thinking':
          _set(VoiceState.thinking);
        case 'speaking':
          // Close the microphone while it talks. Acoustic echo cancellation is
          // supposed to make this unnecessary, and on this hardware it plainly
          // does not: the agent's own sentences came back as user transcript
          // ("कौन सी दाल लक्ष्य भाई..." was its own line), so it answered
          // itself in a loop and re-ran add_to_cart until the cart held four of
          // something the customer asked for twice.
          //
          // A closed microphone cannot hear anything, which is the one
          // guarantee AEC could not give. The cost is that speaking over the
          // agent no longer interrupts it, so the orb becomes a tap-to-
          // interrupt control instead — a deliberate trade of a feature that
          // was not working for behaviour that is correct.
          _setMicOpen(false);
          _set(VoiceState.speaking);
      }
    });

    l.on<ParticipantConnectedEvent>((e) {
      _agentIdentity ??= e.participant.identity;
    });

    l.on<TranscriptionEvent>((e) {
      final fromUser = e.participant.identity == _room?.localParticipant?.identity;
      for (final seg in e.segments) {
        _upsertTurn(
          id: seg.id,
          fromUser: fromUser,
          text: seg.text,
          isFinal: seg.isFinal,
        );
      }
      _armIdle();
      notifyListeners();
    });

    l.on<RoomDisconnectedEvent>((e) {
      if (_disposed) return;
      if (_state == VoiceState.placed) return;
      // The reason matters: a generic "connection broke" told neither the user
      // nor us which side failed. These map to genuinely different problems.
      debugPrint('[VoiceAgent] room disconnected: ${e.reason}');
      lastDisconnectReason = e.reason?.toString();
      _fail(switch (e.reason) {
        DisconnectReason.roomDeleted ||
        DisconnectReason.serverShutdown =>
          'Session poori ho gayi. Dobara shuru karein.',
        DisconnectReason.participantRemoved =>
          'Aapko session se hata diya gaya. Dobara shuru karein.',
        DisconnectReason.joinFailure =>
          'Session join nahi ho paaya. Internet check karke dobara koshish karein.',
        DisconnectReason.duplicateIdentity =>
          'Ek aur session pehle se chal raha hai. Use band karke dobara koshish karein.',
        DisconnectReason.signalingConnectionFailure ||
        DisconnectReason.reconnectAttemptsExceeded =>
          'Network kamzor hai. Behtar signal me dobara koshish karein.',
        _ => 'Connection टूट गया. Dobara shuru karein.',
      });
    });

    // Surfaces whether the agent ever actually arrived. If it never joins, the
    // problem is dispatch or the worker, not the phone.
    l.on<ParticipantDisconnectedEvent>((e) {
      if (e.participant.identity == _agentIdentity) {
        debugPrint('[VoiceAgent] agent left the room');
      }
    });
  }

  /// Folds streaming transcription into readable lines.
  ///
  /// Matching on segment id alone was not enough. Interim results do not always
  /// keep the same id between revisions, so each fragment became its own line
  /// and the screen filled with "Main theekMain theekMain theek hoon. hoon.
  /// hoon." — the agent said it once; the transcript said it three times.
  ///
  /// So: replace by id when we have seen it, otherwise fold into the last line
  /// from the same speaker if that line is still open, and only start a new
  /// line once the previous one is final.
  void _upsertTurn({
    required String id,
    required bool fromUser,
    required String text,
    required bool isFinal,
  }) {
    if (text.isEmpty) return;

    for (final t in turns) {
      if (t.id == id) {
        t.text = text;
        t.isFinal = isFinal;
        return;
      }
    }

    if (turns.isNotEmpty) {
      final last = turns.last;
      if (last.fromUser == fromUser) {
        // Still being revised — fold into it.
        if (!last.isFinal) {
          last.id = id;
          last.text = text;
          last.isFinal = isFinal;
          return;
        }
        // Already closed, but the same sentence arrived again under a fresh
        // segment id. The agent published one line; without this it drew two.
        if (last.text == text) {
          last.id = id;
          last.isFinal = isFinal;
          return;
        }
      }
    }

    turns.add(
      VoiceTurn(fromUser: fromUser, text: text, id: id, isFinal: isFinal),
    );
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

  /// Opens or closes the microphone. Guarded so a burst of state updates does
  /// not thrash the audio track.
  void _setMicOpen(bool open) {
    if (_micOpen == open || _room == null) return;
    _micOpen = open;
    unawaited(
      _room!.localParticipant
          ?.setMicrophoneEnabled(open)
          .catchError((Object e) {
        debugPrint('[VoiceAgent] mic toggle failed: $e');
        return null;
      }),
    );
  }

  /// Cuts the agent off and hands the floor back. Bound to the orb, because
  /// with the microphone closed during speech there is no longer a voice path
  /// to interrupt with.
  Future<void> interrupt() async {
    if (_state != VoiceState.speaking) return;
    AppHaptics.tap();
    _setMicOpen(true);
    _set(VoiceState.listening);
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
