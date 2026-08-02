import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// Where the agent's voice comes out.
///
/// This interface is the seam for swapping the speaking half of the stack. If
/// Gemini's Hindi voice does not sound enough like a kirana bhaiya, a
/// `SarvamBulbulOutput` can implement this and be fed from the output
/// transcript instead of the audio stream, with no change to the session, the
/// tools, or the screen.
abstract class SpeechOutput {
  /// Prepare the audio device. Safe to call more than once.
  Future<void> start();

  /// Queue a chunk of the agent's speech.
  void enqueue(Uint8List pcm);

  /// Drop everything not yet played. This is barge-in: the user has started
  /// talking and the agent must stop mid-word.
  Future<void> flush();

  /// Release the audio device.
  Future<void> stop();
}

/// Plays the raw 24 kHz mono PCM16 that Gemini's native-audio models emit.
///
/// Uses a pull model deliberately. `flutter_pcm_sound` has no "discard the
/// queue" call, so pushing every chunk to the platform as it arrives would put
/// seconds of speech beyond our reach — and barge-in would be a promise we
/// could not keep. Instead the queue lives here in Dart and the platform is fed
/// one small chunk at a time, only when it asks. Flushing then costs one
/// already-submitted chunk of residual audio (~40 ms) rather than everything
/// buffered.
class PcmSpeechOutput implements SpeechOutput {
  /// Gemini native audio output is 24 kHz mono.
  static const int sampleRate = 24000;

  /// 960 samples = 40 ms at 24 kHz. Small enough that residual audio after a
  /// barge-in is inaudible as a word.
  static const int _framesPerFeed = 960;

  final Queue<int> _samples = Queue<int>();
  bool _started = false;

  /// Whether anything is currently queued to play.
  bool get isSpeaking => _samples.isNotEmpty;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await FlutterPcmSound.setLogLevel(LogLevel.error);
    await FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
    // Ask for more audio while roughly two chunks remain, so playback never
    // gaps between chunks but we also never hand over a long tail.
    await FlutterPcmSound.setFeedThreshold(_framesPerFeed * 2);
    FlutterPcmSound.setFeedCallback(_onFeed);
    FlutterPcmSound.start();
  }

  @override
  void enqueue(Uint8List pcm) {
    if (!_started) return;
    // Incoming bytes are little-endian PCM16 and are not guaranteed to start on
    // a two-byte boundary, so read them through a ByteData view.
    final view = ByteData.sublistView(pcm);
    final count = pcm.lengthInBytes ~/ 2;
    for (var i = 0; i < count; i++) {
      _samples.add(view.getInt16(i * 2, Endian.little));
    }
  }

  @override
  Future<void> flush() async {
    _samples.clear();
  }

  @override
  Future<void> stop() async {
    _samples.clear();
    if (!_started) return;
    _started = false;
    FlutterPcmSound.setFeedCallback(null);
    await FlutterPcmSound.release();
  }

  void _onFeed(int remainingFrames) {
    if (!_started) return;

    final take = _samples.length < _framesPerFeed
        ? _samples.length
        : _framesPerFeed;

    // Nothing to say. Hand over a short silence rather than nothing at all:
    // feeding zero frames ends the callback loop, and then the next chunk of
    // real speech would sit in the queue with nothing left to pull it.
    if (take == 0) {
      FlutterPcmSound.feed(PcmArrayInt16.zeros(count: _framesPerFeed ~/ 2));
      return;
    }

    final out = Int16List(take);
    for (var i = 0; i < take; i++) {
      out[i] = _samples.removeFirst();
    }
    FlutterPcmSound.feed(PcmArrayInt16(bytes: ByteData.sublistView(out)));
  }
}

/// Silent implementation, used when speech output is unavailable or disabled.
///
/// Keeps the rest of the feature working — transcript, product cards, cart —
/// so a failure in the audio device degrades the experience instead of ending
/// it.
class NullSpeechOutput implements SpeechOutput {
  @override
  Future<void> start() async {}

  @override
  void enqueue(Uint8List pcm) {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> stop() async {}
}

/// Debug helper: how many samples are waiting. Not used in production paths.
@visibleForTesting
int queuedSamples(PcmSpeechOutput o) => o._samples.length;
