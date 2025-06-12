import 'dart:convert' show jsonEncode;

import 'package:flutter_gherkin_parser/models/background_model.dart';
import 'package:flutter_gherkin_parser/models/scenario_model.dart';

class Feature {
  final String name;
  final String uri;
  final int line;
  final List<String> tags;
  Background? background;
  final List<Scenario> scenarios = [];

  Feature({
    required this.name,
    required this.uri,
    required this.line,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'uri': uri,
      'line': line,
      'tags': tags,
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
  final List<String> tags;

  FeatureInfo({
    required this.featureName,
    required this.uri,
    required this.line,
    this.tags = const [],
  });
}
