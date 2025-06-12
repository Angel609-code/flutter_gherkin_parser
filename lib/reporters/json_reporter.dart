import 'dart:convert';
import 'package:flutter_gherkin_parser/models/feature_model.dart';
import 'package:flutter_gherkin_parser/models/json_step_model.dart';
import 'package:flutter_gherkin_parser/models/report_model.dart';
import 'package:flutter_gherkin_parser/models/scenario_model.dart';
import 'package:flutter_gherkin_parser/reporters/integration_reporter.dart';
import 'package:flutter_gherkin_parser/server/integration_endpoints.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

import '../models/integration_server_result_model.dart';

class JsonReporter extends IntegrationReporter {
  final List<JsonFeature> _features = [];
  JsonScenario? _currentScenario;
  JsonFeature? _currentFeature;

  JsonScenario? _background;
  bool? _inBackground;

  JsonReporter({required super.path});

  @override
  Future<void> onFeatureStarted(FeatureInfo feature) async {
    _currentFeature = JsonFeature(
      uri: feature.uri,
      id : feature.featureName.toLowerCase().replaceAll(' ', '-'),
      name: feature.featureName,
      line: feature.line,
      tags: feature.tags.map((t) => JsonTag(t, feature.line - 1)).toList(),
    );

    _features.add(_currentFeature!);

    _inBackground = true;
    _background = null;
  }

  @override
  Future<void> onBeforeScenario(ScenarioInfo scenario) async {
    _inBackground = false;

    final id = scenario.scenarioName.toLowerCase().replaceAll(' ', '-');
    final scenarioId = '${_currentFeature!.id};$id';
    _currentScenario = JsonScenario(
      id: scenarioId,
      name: scenario.scenarioName,
      line: scenario.line,
      tags: scenario.tags.map((t) => JsonTag(t, scenario.line - 1)).toList(),
    );
    _currentFeature!.elements.add(_currentScenario!);
  }

  @override Future<void> onAfterScenario(String scenarioName) async {
    _inBackground = true;
    _background = null;
  }

  @override
  Future<void> onAfterStep(StepResult result, WidgetTesterWorld world) async {
    if (_inBackground == true && _background == null) {
      _background = JsonScenario(
        id: '${_currentFeature!.id};background',
        keyword: 'Background',
        name: '',
        type: 'background',
        line: result.line - 1,
      );

      _currentFeature!.elements.add(_background!);
    }

    final stepText = result.stepText;
    final line = result.line;
    final parts = stepText.split(' ');
    final keyword = '${parts.first} ';
    final name = parts.skip(1).join(' ');
    String status = result is StepSuccess ? 'passed' : 'failed';

    if (result is StepSkipped) {
      status = 'skipped';
    }

    final jsonStep = JsonStep(
      keyword: keyword,
      name: name,
      line: line,
      status: status,
      errorMessage: result is StepFailure ? '${result.error}' : null,
      duration: result.duration,
      table: result.table,
    );

    if (_inBackground == true) {
      _background?.steps.add(jsonStep);
    } else {
      _currentScenario?.steps.add(jsonStep);
    }
  }

  @override
  Future<void> onAfterAll() async {
    final jsonString = jsonEncode(_features.map((f) => f.toJson()).toList());

    IntegrationServerResult result = await saveReport(ReportBody(
      content: jsonString,
      path: path,
    ));

    if (result.success) {
      print('🟢 Report saved successfully');
    } else {
      print('🔴 Failed to save report ${result.message}');
    }
  }

  @override Future<void> onBeforeAll() async {}
  @override Future<void> onBeforeStep(String stepText, WidgetTesterWorld world) async {}

  @override
  int get priority => 0;

  @override
  Map<String, dynamic> toJson() {
    return {
      'features': _features.map((f) => f.toJson()).toList(),
    };
  }
}
