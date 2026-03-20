import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';
import 'tts_service.dart';

class AmazonPollyTtsService implements ITtsService {
  static const String _accessKey = String.fromEnvironment('AWS_ACCESS_KEY');
  static const String _secretKey = String.fromEnvironment('AWS_SECRET_KEY');
  static const String _region = String.fromEnvironment(
    'AWS_REGION',
    defaultValue: 'us-east-1',
  );
  static const String _voiceId = String.fromEnvironment(
    'AWS_POLLY_VOICE_ID',
    defaultValue: 'Vitoria',
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
  int get currentWordStart =>
      _chunkStarts.isNotEmpty && _currentChunkIndex < _chunkStarts.length
      ? _chunkStarts[_currentChunkIndex]
      : 0;

  @override
  int get currentWordEnd =>
      _chunkStarts.isNotEmpty && _currentChunkIndex < _chunks.length
      ? _chunkStarts[_currentChunkIndex] + _chunks[_currentChunkIndex].length
      : 0;

  AmazonPollyTtsService() {
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

  String _getCacheFileName(String text) {
    final bytes = utf8.encode(text + _voiceId + _region);
    final digest = md5.convert(bytes);
    return "polly_cache_$digest.mp3";
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
    String cleanedText = text
        .replaceAll(RegExp(r'\r'), '')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
    RegExp sentenceSplitter = RegExp(r'(?<=[.!?])\s+');
    List<String> sentences = cleanedText.split(sentenceSplitter);
    String currentChunk = "";
    int chunkStartOffset = 0;
    int runningOffset = 0;
    for (var sentence in sentences) {
      if ((currentChunk.length + sentence.length) > 400 &&
          currentChunk.isNotEmpty) {
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

    if (await cacheFile.exists()) {
      if (executionId == _activeExecutionId) {
        onProgress?.call();
        await _audioPlayer.play(DeviceFileSource(cacheFile.path));
      }
      return;
    }

    if (_accessKey.isEmpty || _secretKey.isEmpty) {
      print("ERRO: AWS Credentials não configuradas");
      return;
    }

    try {
      onProgress?.call();

      final body = utf8.encode(
        jsonEncode({
          "OutputFormat": "mp3",
          "Text": text,
          "VoiceId": _voiceId,
          "Engine": "neural",
        }),
      );

      final signer = AWSSigV4Signer(
        credentialsProvider: AWSCredentialsProvider(
          AWSCredentials(_accessKey, _secretKey),
        ),
      );

      final request = AWSHttpRequest(
        method: AWSHttpMethod.post,
        uri: Uri.parse('https://polly.$_region.amazonaws.com/v1/speech'),
        headers: {
          'Content-Type': 'application/json',
          'Host': 'polly.$_region.amazonaws.com',
        },
        body: body,
      );

      final signedRequest = await signer.sign(
        request,
        credentialScope: AWSCredentialScope(
          region: _region,
          service: AWSService.polly,
        ),
      );

      final response = await http.post(
        signedRequest.uri,
        headers: signedRequest.headers,
        body: body,
      );

      if (executionId != _activeExecutionId) return;

      if (response.statusCode == 200) {
        await cacheFile.writeAsBytes(response.bodyBytes);
        await _audioPlayer.play(DeviceFileSource(cacheFile.path));
      } else {
        print("Erro Amazon Polly: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Erro Amazon Polly: $e");
    }
  }

  void _onChunkCompleted() {
    if (_ttsState == TtsState.stopped &&
        _currentChunkIndex < _chunks.length - 1) {
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
