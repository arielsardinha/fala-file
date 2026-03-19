import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart'; // Para gerar o hash do texto
import 'tts_service.dart';

class ElevenLabsTtsService implements ITtsService {
  static const String _apiKey = String.fromEnvironment('ELEVEN_LABS_API_KEY');
  static const String _voiceId = String.fromEnvironment(
    'ELEVEN_LABS_VOICE_ID',
    defaultValue: 'pNInz6obpgnuM0m4XNNo',
  );

  final AudioPlayer _audioPlayer = AudioPlayer();
  TtsState _ttsState = TtsState.stopped;
  int _activeExecutionId = 0;

  @override
  VoidCallback? onProgress;

  List<String> _chunks = [];
  List<int> _chunkStarts = [];
  int _currentChunkIndex = 0;

  @override
  TtsState get state => _ttsState;

  @override
  double get progress =>
      _chunks.isEmpty ? 0 : (_currentChunkIndex + 1) / _chunks.length;

  @override
  List<String> get chunks => _chunks;

  @override
  int get currentChunkIndex => _currentChunkIndex;

  @override
  int get currentWordStart => _chunkStarts.isNotEmpty && _currentChunkIndex < _chunkStarts.length 
      ? _chunkStarts[_currentChunkIndex] : 0;

  @override
  int get currentWordEnd => _chunkStarts.isNotEmpty && _currentChunkIndex < _chunks.length
      ? _chunkStarts[_currentChunkIndex] + _chunks[_currentChunkIndex].length 
      : 0;

  ElevenLabsTtsService() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (state == PlayerState.playing) {
        _ttsState = TtsState.playing;
      } else if (state == PlayerState.paused) {
        _ttsState = TtsState.paused;
      } else if (state == PlayerState.completed) {
        _ttsState = TtsState.stopped;
        _onChunkCompleted();
      }
      onProgress?.call();
    });
  }

  /// Gera um nome de arquivo único baseado no texto e na voz para o cache
  String _getCacheFileName(String text) {
    // Usamos MD5 para criar um hash curto e único do texto
    final bytes = utf8.encode(text + _voiceId);
    final digest = md5.convert(bytes);
    return "tts_cache_$digest.mp3";
  }

  @override
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (_ttsState == TtsState.paused) {
      await _audioPlayer.resume();
      return;
    }
    _activeExecutionId++;
    _splitIntoChunksWithOffsets(text);
    _currentChunkIndex = 0;
    await _playCurrentChunk(_activeExecutionId);
  }

  void _splitIntoChunksWithOffsets(String text) {
    _chunks = [];
    _chunkStarts = [];
    if (text.isEmpty) return;
    String cleanedText = text.replaceAll(RegExp(r'\r'), '').replaceAll(RegExp(r'\n{2,}'), '\n').trim();
    RegExp sentenceSplitter = RegExp(r'(?<=[.!?])\s+');
    List<String> sentences = cleanedText.split(sentenceSplitter);
    String currentChunk = "";
    int chunkStartOffset = 0;
    int runningOffset = 0;
    for (var sentence in sentences) {
      if ((currentChunk.length + sentence.length) > 400 && currentChunk.isNotEmpty) {
        _chunks.add(currentChunk.trim());
        _chunkStarts.add(chunkStartOffset);
        chunkStartOffset = runningOffset;
        currentChunk = sentence;
      } else {
        if (currentChunk.isEmpty) chunkStartOffset = runningOffset;
        currentChunk += (currentChunk.isEmpty ? "" : " ") + sentence;
      }
      runningOffset += sentence.length + 1;
    }
    if (currentChunk.isNotEmpty) {
      _chunks.add(currentChunk.trim());
      _chunkStarts.add(chunkStartOffset);
    }
  }

  Future<void> _playCurrentChunk(int executionId) async {
    if (_chunks.isEmpty || _currentChunkIndex >= _chunks.length) return;
    
    final String text = _chunks[_currentChunkIndex];
    final String cacheFileName = _getCacheFileName(text);
    final Directory tempDir = await getTemporaryDirectory();
    final File cacheFile = File('${tempDir.path}/$cacheFileName');

    // 1. VERIFICAÇÃO DE CACHE (Economia de Token)
    if (await cacheFile.exists()) {
      print("INFO: Usando áudio do cache local (0 tokens consumidos)");
      if (executionId == _activeExecutionId) {
        onProgress?.call();
        await _audioPlayer.play(DeviceFileSource(cacheFile.path));
      }
      return;
    }

    // 2. CHAMADA À API (Apenas se não houver cache)
    if (_apiKey.isEmpty) return;
    final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId');

    try {
      onProgress?.call();
      final response = await http.post(
        url,
        headers: {
          'xi-api-key': _apiKey,
          'Content-Type': 'application/json',
          'accept': 'audio/mpeg',
        },
        body: jsonEncode({
          "text": text,
          "model_id": "eleven_multilingual_v2",
          "voice_settings": {"stability": 0.5, "similarity_boost": 0.8},
        }),
      );

      if (executionId != _activeExecutionId) return;

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await cacheFile.writeAsBytes(bytes); // Salva no cache para a próxima vez
        await _audioPlayer.play(DeviceFileSource(cacheFile.path));
      } else {
        print("Erro ElevenLabs: ${response.statusCode}");
      }
    } catch (e) {
      print("Erro ElevenLabs: $e");
    }
  }

  void _onChunkCompleted() {
    if (_ttsState == TtsState.stopped && _currentChunkIndex < _chunks.length - 1) {
      _currentChunkIndex++;
      _playCurrentChunk(_activeExecutionId);
    }
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> stop() async {
    _activeExecutionId++;
    await _audioPlayer.stop();
    _currentChunkIndex = 0;
    _ttsState = TtsState.stopped;
    onProgress?.call();
  }

  @override
  Future<void> seekTo(double progress, String text) async {
    _activeExecutionId++;
    await _audioPlayer.stop();
    _ttsState = TtsState.stopped;
    _splitIntoChunksWithOffsets(text);
    if (_chunks.isEmpty) return;
    int targetIndex = (progress * (_chunks.length - 1)).round();
    _currentChunkIndex = targetIndex.clamp(0, _chunks.length - 1);
    await _playCurrentChunk(_activeExecutionId);
  }
}
