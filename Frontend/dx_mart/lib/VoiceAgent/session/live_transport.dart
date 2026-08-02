import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/env.dart';
import '../../core/supabase.dart';

/// The wire to the voice agent.
///
/// Talks to our own `voice-relay` Edge Function, never to Gemini directly. The
/// relay holds GEMINI_API_KEY and composes the session `setup` message, so this
/// class deliberately cannot influence the persona, the model, or the tool
/// list — it only sends microphone audio and tool results, and reads back
/// whatever the model says.
///
/// Uses `IOWebSocketChannel` specifically because it can set request headers on
/// the upgrade; the browser WebSocket API cannot, and the relay authenticates
/// from the `Authorization` header.
class LiveTransport {
  LiveTransport();

  WebSocketChannel? _ch;
  StreamSubscription<dynamic>? _sub;

  /// Server frames, already decoded from JSON.
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  bool get isOpen => _ch != null;

  /// Opens the socket. [resumeHandle] continues a session the server dropped
  /// (Edge Functions cap a socket well before a long order is finished).
  Future<void> connect({String? resumeHandle}) async {
    if (_ch != null) return;

    final token = Db.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw DataException('Voice ordering needs you to be signed in.');
    }

    final base = Env.supabaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final uri = Uri.parse(
      '$base/functions/v1/voice-relay'
      '${resumeHandle != null ? '?resume=${Uri.encodeQueryComponent(resumeHandle)}' : ''}',
    );

    final ch = IOWebSocketChannel.connect(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'apikey': Env.supabaseKey,
      },
      connectTimeout: const Duration(seconds: 15),
    );
    _ch = ch;

    _sub = ch.stream.listen(
      (raw) {
        final text = raw is String ? raw : utf8.decode(raw as List<int>);
        Map<String, dynamic> msg;
        try {
          msg = jsonDecode(text) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        if (!_events.isClosed) _events.add(msg);
      },
      onError: (Object e) {
        if (!_events.isClosed) _events.addError(e);
      },
      onDone: () {
        _ch = null;
        if (!_events.isClosed) _events.add(const {'_closed': true});
      },
      cancelOnError: false,
    );
  }

  /// Streams a chunk of 16 kHz mono PCM16 microphone audio.
  void sendAudio(Uint8List pcm) {
    _send({
      'realtimeInput': {
        'audio': {
          'mimeType': 'audio/pcm;rate=16000',
          'data': base64Encode(pcm),
        },
      },
    });
  }

  /// Sends typed text as a complete turn — the fallback path when speech is not
  /// working or the user would rather type.
  void sendText(String text) {
    _send({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'turnComplete': true,
      },
    });
  }

  /// Returns the result of a tool the model asked us to run.
  void sendToolResponse(
    String id,
    String name,
    Map<String, dynamic> response,
  ) {
    _send({
      'toolResponse': {
        'functionResponses': [
          {'id': id, 'name': name, 'response': response},
        ],
      },
    });
  }

  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _ch?.sink.close();
    } catch (_) {
      // Socket already gone; nothing to close.
    }
    _ch = null;
  }

  Future<void> dispose() async {
    await close();
    await _events.close();
  }

  void _send(Map<String, dynamic> msg) {
    final ch = _ch;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(msg));
    } catch (_) {
      // A dropped frame mid-teardown is not worth surfacing; audio is lossy and
      // the session is about to be re-established anyway.
    }
  }
}
