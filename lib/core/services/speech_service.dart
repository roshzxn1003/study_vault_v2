import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;

  Future<bool> init() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (val) => debugPrint('Speech recognition error: ${val.errorMsg}'),
        onStatus: (val) => debugPrint('Speech status: $val'),
      );
    } catch (e) {
      _isAvailable = false;
    }
    return _isAvailable;
  }

  void startListening(Function(String) onResult) async {
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  void stopListening() async {
    await _speech.stop();
  }

  bool get isAvailable => _isAvailable;
  bool get isListening => _speech.isListening;
}
