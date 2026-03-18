import 'package:fala_file/domain/entities/file_entity.dart';

abstract class FileRepository {
  Future<void> saveFile(FileEntity file);
  Future<List<FileEntity>> getFiles();
  Future<String> extractTextFromPDF(String filePath);
}
