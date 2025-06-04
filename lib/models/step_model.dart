import 'dart:convert' show jsonEncode;

class Step {
  final String text;
  final String source;

  Step({
    required this.text,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'source': source,
    };
  }

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      text: json['text'] as String,
      source: json['source'] as String,
    );
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}