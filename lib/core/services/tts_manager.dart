import 'package:flutter/foundation.dart';
import 'package:fala_file/core/services/tts_service.dart';
import 'package:fala_file/core/services/amazon_polly_tts_service.dart';
import 'package:fala_file/core/services/eleven_labs_tts_service.dart';

enum TtsEngine { flutter_tts, amazon, elevenlabs }

class TtsManager implements ITtsService {
  final FlutterTtsService _flutterTts;
  final AmazonPollyTtsService _amazonPolly;
  final ElevenLabsTtsService _elevenLabs;

  TtsEngine _currentEngine = TtsEngine.flutter_tts;
  TtsEngine get currentEngine => _currentEngine;

  ITtsService get _activeService {
    switch (_currentEngine) {
      case TtsEngine.flutter_tts:
        return _flutterTts;
      case TtsEngine.amazon:
        return _amazonPolly;
      case TtsEngine.elevenlabs:
        return _elevenLabs;
    }
  }

  TtsManager(this._flutterTts, this._amazonPolly, this._elevenLabs);

  void setEngine(TtsEngine engine) {
    if (_currentEngine == engine) return;
    
    // Stop the current service before switching
    _activeService.stop();
    
    _currentEngine = engine;
    
    // Ensure the new active service has the progress callback
    _activeService.onProgress = _onProgress;
  }

  VoidCallback? _onProgress;

  @override
  VoidCallback? get onProgress => _onProgress;

  @override
  set onProgress(VoidCallback? callback) {
    _onProgress = callback;
    _flutterTts.onProgress = callback;
    _amazonPolly.onProgress = callback;
    _elevenLabs.onProgress = callback;
  }

  @override
  TtsState get state => _activeService.state;

  @override
  double get progress => _activeService.progress;

  @override
  List<String> get chunks => _activeService.chunks;

  @override
  int get currentChunkIndex => _activeService.currentChunkIndex;

  @override
  int get currentWordStart => _activeService.currentWordStart;

  @override
  int get currentWordEnd => _activeService.currentWordEnd;

  @override
  Future<void> speak(String text) => _activeService.speak(text);

  @override
  Future<void> pause() => _activeService.pause();

  @override
  Future<void> stop() => _activeService.stop();

  @override
  Future<void> seekTo(double progress, String text) => _activeService.seekTo(progress, text);
}
