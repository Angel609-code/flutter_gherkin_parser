import 'dart:convert' show jsonEncode;

import 'package:flutter_gherkin_parser/models/step_model.dart';

class Scenario {
  final String name;
  final List<Step> steps = [];

  Scenario({required this.name});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}