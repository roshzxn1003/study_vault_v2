import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;

  Future<bool> init({Function(String status)? onStatus, Function(String error)? onError}) async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (val) {
          debugPrint('Speech recognition error: ${val.errorMsg}');
          onError?.call(val.errorMsg);
        },
        onStatus: (val) {
          debugPrint('Speech status: $val');
          onStatus?.call(val);
        },
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

  void startContinuousListening({
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(double soundLevel)? onSoundLevel,
  }) async {
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
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

