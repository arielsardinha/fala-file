import 'package:fala_file/domain/entities/file_entity.dart';
import 'package:fala_file/domain/repositories/file_repository.dart';

class GetFilesUseCase {
  final FileRepository repository;

  GetFilesUseCase(this.repository);

  Future<List<FileEntity>> call() async {
    return await repository.getFiles();
  }
}
