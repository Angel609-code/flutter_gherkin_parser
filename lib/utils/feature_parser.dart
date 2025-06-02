import 'dart:convert';

import 'package:flutter_gherkin_parser/utils/steps_keywords.dart';

class FeatureParser {
  Feature parse(String content) {
    final lines = content.split('\n');
    Feature? feature;
    Scenario? currentScenario;
    bool inBackground = false;

    for (var rawLine in lines) {
      String line = rawLine.trim();

      if (line.startsWith('Feature:')) {
        feature = Feature(name: line.substring('Feature:'.length).trim());
        inBackground = false;
      } else if (line.startsWith('Background:')) {
        // Start collecting background steps
        inBackground = true;
        feature?.background = Background();
      } else if (line.startsWith('Scenario:')) {
        // Stop background collection once a scenario begins
        inBackground = false;
        currentScenario = Scenario(name: line.substring('Scenario:'.length).trim());
        feature?.scenarios.add(currentScenario);
      } else if (stepLinePattern.hasMatch(line)) {
        // It's a step; route to either background or current scenario
        final step = Step(text: line);
        if (inBackground) {
          feature?.background?.steps.add(step);
        } else {
          currentScenario?.steps.add(step);
        }
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
  Background? background;
  final List<Scenario> scenarios = [];

  Feature({required this.name});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (background != null) 'background': background!.toJson(),
      'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

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
