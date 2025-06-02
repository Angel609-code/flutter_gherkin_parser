import 'dart:convert' show jsonEncode;

class Step {
  final String text;
  Step({required this.text});

  Map<String, dynamic> toJson() {
    return {
      'text': text,
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}