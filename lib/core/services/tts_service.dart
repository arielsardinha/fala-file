import 'dart:developer';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, paused, stopped, continued }

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;

  // Pagination/Chunking logic
  List<String> _chunks = [];
  int _currentChunkIndex = 0;
  bool _isManualStop = false;
  String? _lastText;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("pt-BR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      _onChunkCompleted();
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
      log("TTS Error: $msg");
      _ttsState = TtsState.stopped;
    });
  }

  /// Splits text into smaller chunks to avoid long loading times and memory issues.
  List<String> _splitIntoChunks(String text, {int maxChars = 1000}) {
    if (text.isEmpty) return [];
    
    RegExp sentenceSplitter = RegExp(r'(?<=[.!?])\s+');
    List<String> sentences = text.split(sentenceSplitter);
    
    List<String> chunks = [];
    String currentChunk = "";

    for (var sentence in sentences) {
      if ((currentChunk.length + sentence.length) < maxChars) {
        currentChunk += (currentChunk.isEmpty ? "" : " ") + sentence;
      } else {
        if (currentChunk.isNotEmpty) chunks.add(currentChunk);
        currentChunk = sentence;
      }
    }
    
    if (currentChunk.isNotEmpty) chunks.add(currentChunk);
    return chunks;
  }

  Future<void> _onChunkCompleted() async {
    if (_isManualStop) return;

    if (_currentChunkIndex < _chunks.length - 1) {
      _currentChunkIndex++;
      log("Moving to chunk $_currentChunkIndex of ${_chunks.length}");
      await _flutterTts.speak(_chunks[_currentChunkIndex]);
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // If we are already playing this exact text (or paused), just resume
    if (_ttsState == TtsState.paused && _chunks.isNotEmpty && _lastText == text) {
      _isManualStop = false;
      await _flutterTts.speak(_chunks[_currentChunkIndex]);
      return;
    }

    _isManualStop = false;
    _lastText = text;
    _chunks = _splitIntoChunks(text);
    _currentChunkIndex = 0;

    if (_chunks.isNotEmpty) {
      log("Starting playback with ${_chunks.length} chunks");
      await _flutterTts.speak(_chunks[0]);
    }
  }

  Future<void> seekTo(double progress, String text) async {
    // If it's a new text, split it first
    if (_lastText != text || _chunks.isEmpty) {
      _lastText = text;
      _chunks = _splitIntoChunks(text);
    }

    if (_chunks.isEmpty) return;

    // Stop current playback
    _isManualStop = true;
    await _flutterTts.stop();

    // Calculate new index
    int targetIndex = (progress * (_chunks.length - 1)).floor();
    _currentChunkIndex = targetIndex.clamp(0, _chunks.length - 1);

    // Restart from new index
    _isManualStop = false;
    log("Seeking to chunk $_currentChunkIndex (${(progress * 100).toInt()}%)");
    await _flutterTts.speak(_chunks[_currentChunkIndex]);
  }

  Future<void> pause() async {
    _isManualStop = true;
    await _flutterTts.pause();
  }

  Future<void> stop() async {
    _isManualStop = true;
    _chunks = [];
    _currentChunkIndex = 0;
    _lastText = null;
    await _flutterTts.stop();
  }

  TtsState get state => _ttsState;
  
  double get progress => _chunks.isEmpty ? 0 : (_currentChunkIndex + 1) / _chunks.length;
}
