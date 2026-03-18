import 'package:flutter/material.dart';
import 'package:fala_file/domain/entities/file_entity.dart';
import 'package:fala_file/domain/usecases/get_files_use_case.dart';
import 'package:fala_file/domain/usecases/upload_file_use_case.dart';
import 'package:fala_file/core/services/tts_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';

class FileViewModel extends ChangeNotifier {
  final GetFilesUseCase getFilesUseCase;
  final UploadFileUseCase uploadFileUseCase;
  final TtsService ttsService;

  Timer? _ttsUpdateTimer;

  FileViewModel({
    required this.getFilesUseCase,
    required this.uploadFileUseCase,
    required this.ttsService,
  }) {
    // Start a timer to notify UI of progress/state changes while playing
    _ttsUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (ttsService.state == TtsState.playing || ttsService.state == TtsState.continued) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _ttsUpdateTimer?.cancel();
    super.dispose();
  }

  List<FileEntity> _files = [];
  List<FileEntity> get files => _files;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  TtsState get ttsState => ttsService.state;
  double get ttsProgress => ttsService.progress;

  Future<void> loadFiles() async {
    _isLoading = true;
    notifyListeners();

    try {
      _files = await getFilesUseCase();
    } catch (e) {
      debugPrint('Error loading files: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final title = result.files.single.name;

      _isLoading = true;
      notifyListeners();

      try {
        await uploadFileUseCase(path, title);
        await loadFiles();
      } catch (e) {
        debugPrint('Error uploading file: $e');
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // TTS Actions
  Future<void> speak(String text) async {
    await ttsService.speak(text);
    notifyListeners();
  }

  Future<void> pause() async {
    await ttsService.pause();
    notifyListeners();
  }

  Future<void> stop() async {
    await ttsService.stop();
    notifyListeners();
  }
}
