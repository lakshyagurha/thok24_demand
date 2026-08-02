import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Raw microphone capture for the realtime voice session.
///
/// Emits 16 kHz mono PCM16 — the format the Live API expects — in ~40 ms
/// chunks. The chunk size is deliberately small: buffering a second of audio
/// before sending would add a second to every single reply, and this feature
/// lives or dies on answering in under ~800 ms.
///
/// [level] is derived from the PCM bytes themselves rather than from the
/// recorder's separate amplitude stream, so the orb animates off exactly the
/// audio that is being sent, at chunk rate, with no second subscription and no
/// polling timer.
class MicCapture {
  MicCapture({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// The Live API wants 16 kHz mono PCM16.
  static const int sampleRate = 16000;

  /// 16 kHz · mono · 2 bytes = 32 000 B/s, so 1280 bytes is 40 ms.
  static const int _bytesPerChunk = 1280;

  final StreamController<Uint8List> _pcm =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;

  /// Smoothed 0..1 loudness, for the orb. Never dispose this before [dispose].
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  /// 40 ms chunks of 16 kHz mono PCM16, ready to put on the wire.
  Stream<Uint8List> get pcm => _pcm.stream;

  bool get isCapturing => _sub != null;

  /// Whether the microphone is already granted. Triggers the OS prompt if the
  /// user has not been asked yet.
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (_sub != null) return;

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        // Without echo cancellation the speaker feeds straight back into the
        // microphone, so the agent hears its own voice and barges in on itself
        // on every reply. This is not optional for a speaking agent.
        echoCancel: true,
        noiseSuppress: true,
        streamBufferSize: _bytesPerChunk,
      ),
    );

    _sub = stream.listen(
      _onChunk,
      onError: (Object e, StackTrace s) => _pcm.addError(e, s),
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    level.value = 0;
  }

  Future<void> dispose() async {
    await stop();
    await _pcm.close();
    await _recorder.dispose();
    level.dispose();
  }

  void _onChunk(Uint8List chunk) {
    if (_pcm.isClosed) return;
    _pcm.add(chunk);

    // Rise quickly so the orb feels attached to the voice; fall more slowly so
    // it settles instead of strobing between syllables.
    final target = (_rms(chunk) * 5.0).clamp(0.0, 1.0);
    final prev = level.value;
    final k = target > prev ? 0.5 : 0.18;
    level.value = prev + (target - prev) * k;
  }

  /// Root-mean-square of a PCM16 little-endian frame, normalised to 0..1.
  ///
  /// Uses [ByteData.sublistView] rather than `buffer.asInt16List` because the
  /// incoming chunk is a view into a larger buffer and is not guaranteed to
  /// start on a two-byte boundary.
  static double _rms(Uint8List bytes) {
    final samples = bytes.lengthInBytes ~/ 2;
    if (samples == 0) return 0;
    final view = ByteData.sublistView(bytes);
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      final v = view.getInt16(i * 2, Endian.little) / 32768.0;
      sum += v * v;
    }
    return math.sqrt(sum / samples);
  }
}
