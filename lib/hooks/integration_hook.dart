import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

/// Defines lifecycle callbacks for test execution.
///
/// Extend this class to implement logic that runs at different stages:
/// - Before/after all scenarios
/// - Before/after each scenario
/// - Before/after each step
///
/// You may implement multiple hooks and register them together.
/// Hooks with higher [priority] are executed earlier.
abstract class IntegrationHook {
  /// Defines the order in which hooks run.
  /// Hooks are sorted from highest to lowest priority.
  int get priority => 0;

  /// Called once before all scenarios run.
  Future<void> onBeforeAll() async {}

  /// Called once after all scenarios complete.
  Future<void> onAfterAll() async {}

  /// Called before each scenario.
  Future<void> onBeforeScenario(String scenarioName) async {}

  /// Called after each scenario.
  Future<void> onAfterScenario(String scenarioName) async {}

  /// Called before each step.
  Future<void> onBeforeStep(String stepText, WidgetTesterWorld world) async {}

  /// Called after each step.
  Future<void> onAfterStep(String stepText, WidgetTesterWorld world) async {}
}
