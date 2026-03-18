import 'package:fala_file/core/database/database_helper.dart';
import 'package:fala_file/data/models/file_model.dart';

abstract class FileLocalDataSource {
  Future<void> insertFile(FileModel file);
  Future<List<FileModel>> getFiles();
}

class FileLocalDataSourceImpl implements FileLocalDataSource {
  final DatabaseHelper databaseHelper;

  FileLocalDataSourceImpl(this.databaseHelper);

  @override
  Future<void> insertFile(FileModel file) async {
    final db = await databaseHelper.database;
    await db.insert('pdf_files', file.toMap());
  }

  @override
  Future<List<FileModel>> getFiles() async {
    final db = await databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('pdf_files', orderBy: 'id DESC');
    return List.generate(maps.length, (i) {
      return FileModel.fromMap(maps[i]);
    });
  }
}
