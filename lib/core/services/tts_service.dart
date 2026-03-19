import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, paused, stopped, continued }

/// Interface para desacoplamento de motores de Voz
abstract class ITtsService {
  Future<void> speak(String text);
  Future<void> pause();
  Future<void> stop();
  Future<void> seekTo(double progress, String text);
  
  TtsState get state;
  double get progress;
  VoidCallback? onProgress;
  
  List<String> get chunks;
  int get currentChunkIndex;
  int get currentWordStart;
  int get currentWordEnd;
}

/// Implementação utilizando o pacote nativo flutter_tts
class FlutterTtsService implements ITtsService {
  final FlutterTts _flutterTts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;
  
  @override
  VoidCallback? onProgress;

  List<String> _chunks = [];
  int _currentChunkIndex = 0;
  bool _isManualStop = false;
  String? _lastText;

  int _currentWordStart = 0;
  int _currentWordEnd = 0;

  @override
  List<String> get chunks => _chunks;
  @override
  int get currentChunkIndex => _currentChunkIndex;
  @override
  int get currentWordStart => _currentWordStart;
  @override
  int get currentWordEnd => _currentWordEnd;
  @override
  TtsState get state => _ttsState;
  @override
  double get progress => _chunks.isEmpty ? 0 : (_currentChunkIndex + 1) / _chunks.length;

  FlutterTtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.38);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    await _setupBestVoice();

    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
      onProgress?.call();
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      _onChunkCompleted();
    });

    _flutterTts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
      onProgress?.call();
    });

    _flutterTts.setPauseHandler(() {
      _ttsState = TtsState.paused;
      onProgress?.call();
    });

    _flutterTts.setContinueHandler(() {
      _ttsState = TtsState.continued;
      onProgress?.call();
    });

    _flutterTts.setErrorHandler((msg) {
      log("TTS Error: $msg");
      _ttsState = TtsState.stopped;
      onProgress?.call();
    });

    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      _currentWordStart = start;
      _currentWordEnd = end;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_ttsState == TtsState.playing || _ttsState == TtsState.continued) {
          onProgress?.call();
        }
      });
    });
  }

  Future<void> _setupBestVoice() async {
    try {
      if (Platform.isAndroid) {
        await _flutterTts.setEngine("com.google.android.tts");
      }

      List<dynamic>? voices = await _flutterTts.getVoices;
      if (voices != null) {
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

  List<String> _splitIntoChunks(String text, {int maxChars = 400}) {
    if (text.isEmpty) return [];
    String cleanedText = text.replaceAll(RegExp(r'\n{2,}'), '\n').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    RegExp sentenceSplitter = RegExp(r'(?<=[.!?])\s+');
    List<String> sentences = cleanedText.split(sentenceSplitter);
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
    _currentWordStart = 0;
    _currentWordEnd = 0;
    onProgress?.call();
    if (_currentChunkIndex < _chunks.length - 1) {
      _currentChunkIndex++;
      await _flutterTts.speak(_chunks[_currentChunkIndex]);
    }
  }

  @override
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (_ttsState == TtsState.paused && _chunks.isNotEmpty && _lastText == text) {
      _isManualStop = false;
      await _flutterTts.speak(_chunks[_currentChunkIndex]);
      return;
    }
    _isManualStop = false;
    _lastText = text;
    _chunks = _splitIntoChunks(text);
    _currentChunkIndex = 0;
    _currentWordStart = 0;
    _currentWordEnd = 0;
    if (_chunks.isNotEmpty) await _flutterTts.speak(_chunks[0]);
  }

  @override
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
    _currentWordStart = 0;
    _currentWordEnd = 0;
    _isManualStop = false;
    await _flutterTts.speak(_chunks[_currentChunkIndex]);
  }

  @override
  Future<void> pause() async {
    _isManualStop = true;
    await _flutterTts.pause();
  }

  @override
  Future<void> stop() async {
    _isManualStop = true;
    _chunks = [];
    _currentChunkIndex = 0;
    _currentWordStart = 0;
    _currentWordEnd = 0;
    _lastText = null;
    await _flutterTts.stop();
  }
}
