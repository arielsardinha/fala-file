import 'package:fala_file/domain/entities/file_entity.dart';
import 'package:fala_file/domain/repositories/file_repository.dart';

class UploadFileUseCase {
  final FileRepository repository;

  UploadFileUseCase(this.repository);

  Future<void> call(String filePath, String title) async {
    final text = await repository.extractTextFromPDF(filePath);
    final file = FileEntity(
      title: title,
      content: text,
      uploadDate: DateTime.now(),
    );
    await repository.saveFile(file);
  }
}
