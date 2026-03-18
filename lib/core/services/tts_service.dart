import 'dart:developer';

import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, paused, stopped, continued }

class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static TtsState _ttsState = TtsState.stopped;

  static Future<void> initTts() async {
    await _flutterTts.setLanguage("pt-BR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
    });

    _flutterTts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
    });

    _flutterTts.setPauseHandler(() {
      _ttsState = TtsState.paused;
    });

    _flutterTts.setContinueHandler(() {
      _ttsState = TtsState.continued;
    });

    _flutterTts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
    });
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      try {
        await _flutterTts.speak(text);
      } catch (e) {
        log(e.toString());
      }
    }
  }

  Future<void> pause() async {
    await _flutterTts.pause();
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  TtsState get state => _ttsState;
}
