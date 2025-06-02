import 'dart:convert' show jsonEncode;

import 'package:flutter_gherkin_parser/models/step_model.dart';

class Background {
  final List<Step> steps = [];

  Map<String, dynamic> toJson() {
    return {
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}