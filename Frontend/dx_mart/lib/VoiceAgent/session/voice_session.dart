import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../CustomWidgets/cart_provider.dart';
import '../../core/supabase.dart';
import '../../design/haptics.dart';
import '../audio/mic_capture.dart';
import '../audio/speech_output.dart';
import '../models/voice_state.dart';
import '../tools/tool_dispatcher.dart';
import 'live_transport.dart';

/// One line of the conversation ribbon.
class VoiceTurn {
  VoiceTurn({required this.fromUser, required this.text});
  final bool fromUser;
  String text;
}

/// Orchestrates one voice ordering session.
///
/// Scoped to the route rather than the app, so the socket, the microphone and
/// the audio device are all released when the page closes.
class VoiceSession extends ChangeNotifier {
  VoiceSession({required CartProvider cart, SpeechOutput? output})
      : _speech = output ?? PcmSpeechOutput() {
    _tools = ToolDispatcher(cart: cart, onCardsChanged: notifyListeners);
  }

  final MicCapture _mic = MicCapture();
  final LiveTransport _transport = LiveTransport();
  final SpeechOutput _speech;
  late final ToolDispatcher _tools;

  StreamSubscription<Map<String, dynamic>>? _events;
  StreamSubscription<Uint8List>? _audio;
  Timer? _silence;

  VoiceState _state = VoiceState.idle;
  String? _error;
  String? _resumeHandle;
  bool _disposed = false;

  /// True once the session has been closed for good and must not reconnect.
  bool _finished = false;

  final List<VoiceTurn> turns = [];

  VoiceState get state => _state;
  String? get error => _error;
  ValueListenable<double> get level => _mic.level;
  List<VoiceCard> get cards => _tools.cards;
  bool get ordered => _tools.ordered;

  /// Sessions are capped so a phone left face-down in a pocket cannot bill an
  /// open socket indefinitely.
  static const Duration _idleTimeout = Duration(seconds: 45);

  // ---------------------------------------------------------------------------

  Future<void> start() async {
    if (_state.isLive) return;
    _set(VoiceState.connecting, error: null);

    if (!Db.isSignedIn) {
      _fail('Voice ordering ke liye sign in karna hoga.');
      return;
    }

    if (!await _mic.hasPermission()) {
      _fail('Mic ki permission chahiye. Phone Settings → Apps → DxMart → '
          'Permissions se mic on karein.');
      return;
    }

    try {
      await _speech.start();
      await _transport.connect(resumeHandle: _resumeHandle);
      _events = _transport.events.listen(_onEvent, onError: (Object e) {
        _fail('Connection टूट गया. Dobara koshish karein.');
      });

      await _mic.start();
      _audio = _mic.pcm.listen(_transport.sendAudio);

      AppHaptics.tap();
      _set(VoiceState.listening);
      _armIdleTimeout();
    } catch (e) {
      _fail('Voice shuru nahi ho paaya. Dobara koshish karein.');
    }
  }

  Future<void> stop() async {
    _finished = true;
    _silence?.cancel();
    await _audio?.cancel();
    _audio = null;
    await _mic.stop();
    await _events?.cancel();
    _events = null;
    await _transport.close();
    await _speech.flush();
    await _speech.stop();
    if (_state != VoiceState.placed) _set(VoiceState.idle);
  }

  /// The typed fallback. Voice must never be the only way through.
  void sendText(String text) {
    final t = text.trim();
    if (t.isEmpty || !_transport.isOpen) return;
    turns.add(VoiceTurn(fromUser: true, text: t));
    _transport.sendText(t);
    _set(VoiceState.thinking);
  }

  // ---------------------------------------------------------------------------

  void _onEvent(Map<String, dynamic> msg) {
    if (_disposed) return;
    _armIdleTimeout();

    if (msg['_closed'] == true) {
      _onSocketClosed();
      return;
    }

    // Keep the latest resumption handle so a server-side drop can be stitched
    // back together instead of restarting the conversation.
    final resumption = msg['sessionResumptionUpdate'];
    if (resumption is Map && resumption['newHandle'] is String) {
      _resumeHandle = resumption['newHandle'] as String;
    }

    // The server is about to close. Reconnect before it does, not after.
    if (msg['goAway'] != null && !_finished) {
      unawaited(_reconnect());
      return;
    }

    final toolCall = msg['toolCall'];
    if (toolCall is Map && toolCall['functionCalls'] is List) {
      for (final raw in toolCall['functionCalls'] as List) {
        if (raw is Map) unawaited(_runTool(raw));
      }
    }

    final sc = msg['serverContent'];
    if (sc is! Map) return;

    // Barge-in. Drop queued speech in the same turn we hear about it.
    if (sc['interrupted'] == true) {
      unawaited(_speech.flush());
      _set(VoiceState.listening);
    }

    final input = sc['inputTranscription'];
    if (input is Map && input['text'] is String) {
      _appendTurn(fromUser: true, text: input['text'] as String);
    }

    final output = sc['outputTranscription'];
    if (output is Map && output['text'] is String) {
      _appendTurn(fromUser: false, text: output['text'] as String);
      if (_state != VoiceState.speaking) _set(VoiceState.speaking);
    }

    final modelTurn = sc['modelTurn'];
    if (modelTurn is Map && modelTurn['parts'] is List) {
      for (final part in modelTurn['parts'] as List) {
        if (part is! Map) continue;
        final inline = part['inlineData'];
        if (inline is Map && inline['data'] is String) {
          _speech.enqueue(base64Decode(inline['data'] as String));
          if (_state != VoiceState.speaking) _set(VoiceState.speaking);
        }
      }
    }

    if (sc['turnComplete'] == true) {
      _set(_tools.ordered ? VoiceState.placed : VoiceState.listening);
    }
  }

  Future<void> _runTool(Map raw) async {
    final id = raw['id']?.toString() ?? '';
    final name = raw['name']?.toString() ?? '';
    final args = (raw['args'] is Map)
        ? Map<String, dynamic>.from(raw['args'] as Map)
        : <String, dynamic>{};

    if (name == 'place_order') _set(VoiceState.placing);

    final result = await _tools.call(name, args);
    if (_disposed) return;

    if (result['ok'] == true && name == 'add_to_cart') AppHaptics.tap();
    if (result['ok'] == true && name == 'place_order') AppHaptics.success();
    if (result['ok'] != true && name == 'place_order') AppHaptics.error();

    _transport.sendToolResponse(id, name, result);
    notifyListeners();
  }

  void _onSocketClosed() {
    if (_finished || _disposed) return;
    // Edge Functions cap a socket well short of a leisurely grocery order, so a
    // close mid-conversation is expected rather than exceptional.
    if (_resumeHandle != null) {
      unawaited(_reconnect());
    } else {
      _fail('Connection टूट गया. Dobara shuru karein.');
    }
  }

  Future<void> _reconnect() async {
    if (_finished || _disposed) return;
    try {
      await _audio?.cancel();
      _audio = null;
      await _events?.cancel();
      _events = null;
      await _transport.close();

      await _transport.connect(resumeHandle: _resumeHandle);
      _events = _transport.events.listen(_onEvent, onError: (Object e) {
        _fail('Connection टूट गया. Dobara koshish karein.');
      });
      _audio = _mic.pcm.listen(_transport.sendAudio);
      if (!_disposed) _set(VoiceState.listening);
    } catch (_) {
      _fail('Connection wapas nahi jud paaya.');
    }
  }

  void _appendTurn({required bool fromUser, required String text}) {
    if (text.isEmpty) return;
    // Transcription arrives in fragments; append to the open turn rather than
    // creating a line per syllable.
    if (turns.isNotEmpty && turns.last.fromUser == fromUser) {
      turns.last.text += text;
    } else {
      turns.add(VoiceTurn(fromUser: fromUser, text: text));
    }
    if (turns.length > 40) turns.removeRange(0, turns.length - 40);
    notifyListeners();
  }

  void _armIdleTimeout() {
    _silence?.cancel();
    _silence = Timer(_idleTimeout, () {
      if (_state.isLive) unawaited(stop());
    });
  }

  void _fail(String message) {
    _error = message;
    _set(VoiceState.failed);
    AppHaptics.error();
    unawaited(_teardownQuietly());
  }

  Future<void> _teardownQuietly() async {
    _silence?.cancel();
    await _audio?.cancel();
    _audio = null;
    await _mic.stop();
    await _transport.close();
    await _speech.flush();
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
    _finished = true;
    _silence?.cancel();
    unawaited(_audio?.cancel());
    unawaited(_events?.cancel());
    unawaited(_mic.dispose());
    unawaited(_transport.dispose());
    unawaited(_speech.stop());
    super.dispose();
  }
}
