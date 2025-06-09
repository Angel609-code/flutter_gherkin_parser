import 'dart:convert' show jsonEncode;

class Step {
  final String text;
  final int line;

  Step({
    required this.text,
    required this.line,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'line': line,
    };
  }

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      text: json['text'] as String,
      line: json['line'] as int,
    );
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}