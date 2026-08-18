import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records one spoken turn and returns the audio bytes, using amplitude-based
/// voice-activity detection to auto-detect when the speaker stops (endpointing).
abstract class AudioCapture {
  Future<bool> ensurePermission();

  /// Records until the speaker pauses (or a max duration). Returns the encoded
  /// audio bytes, or null if nothing was said or the turn was aborted via [stop].
  Future<Uint8List?> captureTurn();

  Future<void> stop();
}

class AudioCaptureService implements AudioCapture {
  final AudioRecorder _rec = AudioRecorder();

  // Active-turn handles so stop() can settle an in-flight capture.
  Completer<void>? _active;
  StreamSubscription<Amplitude>? _sub;
  bool _aborted = false;

  // VAD tuning — amplitudes are dBFS (0 = loudest, more negative = quieter).
  static const double _speechThresholdDb = -30.0;
  static const Duration _pollInterval = Duration(milliseconds: 200);
  static const Duration _silenceToEnd = Duration(milliseconds: 1400);
  static const Duration _maxTurn = Duration(seconds: 20);
  static const Duration _noSpeechTimeout = Duration(seconds: 8);

  @override
  Future<bool> ensurePermission() => _rec.hasPermission();

  @override
  Future<Uint8List?> captureTurn() async {
    if (!await _rec.hasPermission()) return null;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/turn_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _rec.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1),
      path: path,
    );

    _aborted = false;
    final done = Completer<void>();
    _active = done;
    var speechStarted = false;
    var silenceMs = 0;
    final start = DateTime.now();

    void finish() {
      if (!done.isCompleted) done.complete();
    }

    _sub = _rec.onAmplitudeChanged(_pollInterval).listen((amp) {
      if (done.isCompleted) return;
      final elapsed = DateTime.now().difference(start);
      if (elapsed >= _maxTurn) {
        finish();
        return;
      }
      if (amp.current > _speechThresholdDb) {
        speechStarted = true;
        silenceMs = 0;
      } else if (speechStarted) {
        silenceMs += _pollInterval.inMilliseconds;
        if (silenceMs >= _silenceToEnd.inMilliseconds) finish();
      } else if (elapsed >= _noSpeechTimeout) {
        finish(); // gave up waiting for any speech
      }
    });

    await done.future;
    await _sub?.cancel();
    _sub = null;
    _active = null;

    if (_aborted) {
      // stop() already halted the recorder and owns cleanup.
      return null;
    }

    final resultPath = await _rec.stop();
    if (!speechStarted || resultPath == null) {
      _tryDelete(resultPath ?? path);
      return null;
    }
    try {
      final bytes = await File(resultPath).readAsBytes();
      _tryDelete(resultPath);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> stop() async {
    _aborted = true;
    await _sub?.cancel();
    _sub = null;
    final active = _active;
    _active = null;
    if (active != null && !active.isCompleted) active.complete();
    if (await _rec.isRecording()) await _rec.stop();
  }

  void _tryDelete(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}
