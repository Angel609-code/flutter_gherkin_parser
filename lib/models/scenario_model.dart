import 'dart:convert' show jsonEncode;

import 'package:flutter_gherkin_parser/models/step_model.dart';

class Scenario {
  final String name;
  final int line;
  final List<Step> steps = [];

  Scenario({
    required this.name,
    required this.line,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'line': line,
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

class ScenarioInfo {
  final String scenarioName;
  final int line;

  ScenarioInfo({
    required this.scenarioName,
    required this.line,
  });
}
