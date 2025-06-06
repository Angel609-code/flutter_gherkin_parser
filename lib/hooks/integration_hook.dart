import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';
import '../steps/step_result.dart';

/// Defines lifecycle callbacks for integration‐test execution.
///
/// Extend this class to implement logic that runs at different stages:
/// - Before/after all scenarios
/// - Before/after each scenario
/// - Before/after each step
///
/// Hooks are sorted by [priority] (higher value runs first).
abstract class IntegrationHook {
  /// Determines the order in which hooks execute.
  /// Hooks with higher [priority] run earlier.
  int get priority => 0;

  /// Called once before any scenario is executed.
  Future<void> onBeforeAll() async {}

  /// Called once after all scenarios have finished.
  Future<void> onAfterAll() async {}

  /// Called before each scenario, passing its name.
  Future<void> onBeforeScenario(String scenarioName) async {}

  /// Called after each scenario has finished, passing its name.
  Future<void> onAfterScenario(String scenarioName) async {}

  /// Called immediately before a single step is executed.
  ///
  /// [stepText] is the raw Gherkin step, [world] is your test world.
  Future<void> onBeforeStep(String stepText, WidgetTesterWorld world) async {}

  /// Called immediately after a single step finishes.
  ///
  /// [result] is either a [StepSuccess] or a [StepFailure].
  /// [world] is your test world.
  Future<void> onAfterStep(StepResult result, WidgetTesterWorld world) async {}
}
