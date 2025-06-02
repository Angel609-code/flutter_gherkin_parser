import 'dart:convert' show jsonEncode;

import 'package:flutter_gherkin_parser/models/background_model.dart';
import 'package:flutter_gherkin_parser/models/scenario_model.dart';

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