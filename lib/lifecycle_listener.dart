import 'package:flutter_gherkin_parser/models/feature_model.dart';
import 'package:flutter_gherkin_parser/models/scenario_model.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

abstract class LifecycleListener {
  int get priority => 0;

  Future<void> onBeforeAll() async {}

  Future<void> onAfterAll() async {}

  Future<void> onFeatureStarted(FeatureInfo feature) async {}

  Future<void> onBeforeScenario(ScenarioInfo scenario) async {}

  Future<void> onAfterScenario(String scenarioName) async {}

  Future<void> onBeforeStep(String stepText, WidgetTesterWorld world) async {}

  Future<void> onAfterStep(StepResult result, WidgetTesterWorld world) async {}
}
