import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';

bool shouldUseFallback(List<int>? mp3Bytes) => mp3Bytes == null || mp3Bytes.isEmpty;

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool usedFallbackLast = false;

  Future<void> speak({Uint8List? mp3Bytes, required String fallbackText}) async {
    if (shouldUseFallback(mp3Bytes)) {
      usedFallbackLast = true;
      await _tts.speak(fallbackText);
      return;
    }
    usedFallbackLast = false;
    await _player.setAudioSource(_BytesSource(mp3Bytes!));
    await _player.play();
  }
}

class _BytesSource extends StreamAudioSource {
  final Uint8List _bytes;
  _BytesSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
