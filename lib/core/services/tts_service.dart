import 'dart:developer';
import 'dart:io';
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
    // Basic settings for pt-BR
    // Fine-tuning for more natural sound
    // 0.4 to 0.45 is usually more "human" for long reading than 0.5
    await _flutterTts.setSpeechRate(0.42);
    await _flutterTts.setVolume(1.0);

    // Pitch slightly below 1.0 (e.g., 0.9) often sounds more natural/mature
    await _flutterTts.setPitch(0.9);

    // Try to set a high-quality voice if available
    await _setupBestVoice();

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

  /// Tries to find and set the most natural sounding voice available for pt-BR
  Future<void> _setupBestVoice() async {
    try {
      if (Platform.isAndroid) {
        // Ensure we are using Google engine if possible
        await _flutterTts.setEngine("com.google.android.tts");
      }

      List<dynamic>? voices = await _flutterTts.getVoices;
      if (voices != null) {
        // Look for voices that are pt-BR and likely to be high quality (Neural/Natural)
        // Common patterns for high-quality Google voices: "pt-br-x-afs", "neural"
        var bestVoice = voices.firstWhere(
          (voice) =>
              voice["locale"].toString().contains("pt-BR") &&
              (voice["name"].toString().toLowerCase().contains("neural") ||
                  voice["name"].toString().toLowerCase().contains("afs") ||
                  voice["name"].toString().toLowerCase().contains("network")),
          orElse: () => voices.firstWhere(
            (voice) => voice["locale"].toString().contains("pt-BR"),
            orElse: () => null,
          ),
        );

        if (bestVoice != null) {
          log("Setting best available voice: ${bestVoice["name"]}");
          await _flutterTts.setLanguage(bestVoice['locale']);
          await _flutterTts.setVoice({
            "name": bestVoice["name"],
            "locale": bestVoice["locale"],
          });
        }
      }
    } catch (e) {
      log("Error setting up best voice: $e");
    }
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

    if (_ttsState == TtsState.paused &&
        _chunks.isNotEmpty &&
        _lastText == text) {
      _isManualStop = false;
      await _flutterTts.speak(_chunks[_currentChunkIndex]);
      return;
    }

    _isManualStop = false;
    _lastText = text;
    _chunks = _splitIntoChunks(text);
    _currentChunkIndex = 0;

    if (_chunks.isNotEmpty) {
      await _flutterTts.speak(_chunks[0]);
    }
  }

  Future<void> seekTo(double progress, String text) async {
    if (_lastText != text || _chunks.isEmpty) {
      _lastText = text;
      _chunks = _splitIntoChunks(text);
    }

    if (_chunks.isEmpty) return;

    _isManualStop = true;
    await _flutterTts.stop();

    int targetIndex = (progress * (_chunks.length - 1)).floor();
    _currentChunkIndex = targetIndex.clamp(0, _chunks.length - 1);

    _isManualStop = false;
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

  double get progress =>
      _chunks.isEmpty ? 0 : (_currentChunkIndex + 1) / _chunks.length;
}
