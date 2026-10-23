import 'dart:ui';
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  TextToSpeechService() {
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  void setCompletionHandler(VoidCallback callback) {
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      callback();
    });
  }

  void setStartHandler(VoidCallback callback) {
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      callback();
    });
  }

  void setErrorHandler(Function(dynamic) callback) {
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      callback(msg);
    });
  }

  Future<void> speak(String text, {String language = 'en-US', double rate = 0.5}) async {
    _isSpeaking = true;
    await _flutterTts.setLanguage(language);
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _flutterTts.stop();
  }

  Future<void> pause() async {
    await _flutterTts.pause();
  }

  Future<void> resume() async {
    // await _flutterTts.resume();
  }

  bool get isSpeaking => _isSpeaking;
}

