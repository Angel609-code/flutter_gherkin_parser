import 'dart:convert';

import 'package:flutter_gherkin_parser/models/gherkin_table_model.dart';

class JsonStep {
  final String keyword;
  final String name;
  final int line;
  final String status;
  final String? errorMessage;
  final int? duration;
  final GherkinTable? table;

  const JsonStep({
    required this.keyword,
    required this.name,
    required this.line,
    required this.status,
    this.errorMessage,
    this.duration,
    this.table,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{
      'keyword': keyword,
      'name': name,
      'line': line,
      'result': <String, dynamic>{
        'status': status,
      },
      if (table != null) 'rows': table!.toJsonRows(),
    };

    final inner = result['result'] as Map<String, dynamic>;
    if (duration != null) {
      inner['duration'] = duration;
    }
    if (errorMessage != null) {
      inner['error_message'] = errorMessage;
    }
    return result;
  }

  @override
  String toString() => jsonEncode(toJson());
}

class JsonScenario {
  final String id;
  final String keyword;
  final String name;
  final String description;
  final String type;
  final int line;
  final List<JsonTag> tags;
  final List<JsonStep> steps;

  JsonScenario({
    required this.id,
    this.keyword = 'Scenario',
    required this.name,
    this.description = '',
    this.type = 'scenario',
    required this.line,
    this.tags = const <JsonTag>[],
    List<JsonStep>? steps,
  }) : steps = steps ?? <JsonStep>[];

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'keyword': keyword,
    'name': name,
    'description': description,
    'type': type,
    'line': line,
    'tags': tags,
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  @override
  String toString() => jsonEncode(toJson());
}

class JsonFeature {
  final String uri;
  final String id;
  final String keyword;
  final String name;
  final String description;
  final int line;
  final List<JsonTag> tags;
  final List<JsonScenario> elements;

  JsonFeature({
    required this.uri,
    required this.id,
    this.keyword = 'Feature',
    required this.name,
    this.description = '',
    required this.line,
    this.tags = const <JsonTag>[],
  List<JsonScenario>? elements,
  }) : elements = elements ?? <JsonScenario>[];

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uri': uri,
    'id': id,
    'keyword': keyword,
    'name': name,
    'description': description,
    'line': line,
    'tags': tags,
    'elements': elements.map((e) => e.toJson()).toList(),
  };

  @override
  String toString() => jsonEncode(toJson());
}

class JsonTag {
  final String name;
  final int line;

  JsonTag(this.name, this.line);

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'line': line,
    };
  }
}

