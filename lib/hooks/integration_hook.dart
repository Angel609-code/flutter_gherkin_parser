import 'package:flutter_gherkin_parser/lifecycle_listener.dart';
import 'package:flutter_gherkin_parser/models/feature_model.dart';
import 'package:flutter_gherkin_parser/models/scenario_model.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

abstract class IntegrationHook implements LifecycleListener {
  @override
  int get priority => 0;

  @override
  Future<void> onBeforeAll() async {}

  @override
  Future<void> onFeatureStarted(FeatureInfo feature) async {}

  @override
  Future<void> onAfterAll() async {}

  @override
  Future<void> onBeforeScenario(ScenarioInfo scenario) async {}

  @override
  Future<void> onAfterScenario(String scenarioName) async {}

  @override
  Future<void> onBeforeStep(String stepText, WidgetTesterWorld world) async {}

  @override
  Future<void> onAfterStep(StepResult result, WidgetTesterWorld world) async {}
}
