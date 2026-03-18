import 'package:fala_file/data/datasources/file_local_datasource.dart';
import 'package:fala_file/data/datasources/pdf_datasource.dart';
import 'package:fala_file/data/models/file_model.dart';
import 'package:fala_file/domain/entities/file_entity.dart';
import 'package:fala_file/domain/repositories/file_repository.dart';

class FileRepositoryImpl implements FileRepository {
  final FileLocalDataSource localDataSource;
  final PDFDataSource pdfDataSource;

  FileRepositoryImpl({
    required this.localDataSource,
    required this.pdfDataSource,
  });

  @override
  Future<void> saveFile(FileEntity file) async {
    await localDataSource.insertFile(FileModel.fromEntity(file));
  }

  @override
  Future<List<FileEntity>> getFiles() async {
    return await localDataSource.getFiles();
  }

  @override
  Future<String> extractTextFromPDF(String filePath) async {
    return await pdfDataSource.extractText(filePath);
  }
}
