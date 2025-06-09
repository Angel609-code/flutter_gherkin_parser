class ReportBody {
  final String content;
  final String path;

  ReportBody({
    required this.content,
    required this.path,
  });

  Map<String, dynamic> toJson() => {
    'content': content,
    'path': path,
  };
}
