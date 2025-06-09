import 'dart:convert' show jsonEncode;

import 'package:flutter_gherkin_parser/models/background_model.dart';
import 'package:flutter_gherkin_parser/models/scenario_model.dart';

class Feature {
  final String name;
  final String uri;
  final int line;
  Background? background;
  final List<Scenario> scenarios = [];

  Feature({
    required this.name,
    required this.uri,
    required this.line,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'uri': uri,
      'line': line,
      if (background != null) 'background': background!.toJson(),
      'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

class FeatureInfo {
  final String featureName;
  final String uri;
  final int line;

  FeatureInfo({
    required this.featureName,
    required this.uri,
    required this.line,
  });
}
