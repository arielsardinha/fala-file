class FileEntity {
  final int? id;
  final String title;
  final String content;
  final DateTime uploadDate;

  FileEntity({
    this.id,
    required this.title,
    required this.content,
    required this.uploadDate,
  });
}
