import 'package:speech_to_text/speech_to_text.dart' as stt;

abstract class SttService {
  Future<bool> init();
  Future<void> startListening(void Function(String partial) onResult);
  Future<String> stopListening();
  bool get isListening;
}

class SpeechToTextService implements SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _lastWords = '';

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> init() => _speech.initialize();

  @override
  Future<void> startListening(void Function(String) onResult) async {
    _lastWords = '';
    await _speech.listen(onResult: (r) {
      _lastWords = r.recognizedWords;
      onResult(_lastWords);
    });
  }

  @override
  Future<String> stopListening() async {
    await _speech.stop();
    return _lastWords;
  }
}
