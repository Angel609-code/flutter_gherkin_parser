import 'dart:convert';

import 'package:flutter_gherkin_parser/utils/steps_keywords.dart';

class FeatureParser {
  Feature parse(String content) {
    final lines = content.split('\n');
    Feature? feature;
    Scenario? currentScenario;

    for (var line in lines) {
      line = line.trim();

      if (line.startsWith('Feature:')) {
        feature = Feature(name: line.substring('Feature:'.length).trim());
      } else if (line.startsWith('Scenario:')) {
        currentScenario = Scenario(name: line.substring('Scenario:'.length).trim());
        feature?.scenarios.add(currentScenario);
      } else if (stepLinePattern.hasMatch(line)) {
        currentScenario?.steps.add(Step(text: line));
      }
    }

    if (feature == null) {
      throw Exception('No feature found in file.');
    }

    return feature;
  }
}

class Feature {
  final String name;
  final List<Scenario> scenarios = [];
  Feature({required this.name});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

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
