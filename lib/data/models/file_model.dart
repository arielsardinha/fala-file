import 'package:fala_file/domain/entities/file_entity.dart';

class FileModel extends FileEntity {
  FileModel({
    super.id,
    required super.title,
    required super.content,
    required super.uploadDate,
  });

  factory FileModel.fromMap(Map<String, dynamic> map) {
    return FileModel(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      uploadDate: DateTime.parse(map['upload_date']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'content': content,
      'upload_date': uploadDate.toIso8601String(),
    };
  }

  factory FileModel.fromEntity(FileEntity entity) {
    return FileModel(
      id: entity.id,
      title: entity.title,
      content: entity.content,
      uploadDate: entity.uploadDate,
    );
  }
}
