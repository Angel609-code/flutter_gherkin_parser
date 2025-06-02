import 'package:flutter_gherkin_parser/hooks/integration_hook.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

class HookManager {
  final List<IntegrationHook> _hooks;

  HookManager(List<IntegrationHook> hooks) : _hooks = [...hooks]..sort((a, b) => b.priority.compareTo(a.priority));

  Future<void> beforeAll() async {
    for (final hook in _hooks) {
      await hook.onBeforeAll();
    }
  }

  Future<void> afterAll() async {
    for (final hook in _hooks) {
      await hook.onAfterAll();
    }
  }

  Future<void> beforeScenario(String scenarioName) async {
    for (final hook in _hooks) {
      await hook.onBeforeScenario(scenarioName);
    }
  }

  Future<void> afterScenario(String scenarioName) async {
    for (final hook in _hooks) {
      await hook.onAfterScenario(scenarioName);
    }
  }

  Future<void> beforeStep(String stepText, WidgetTesterWorld world) async {
    for (final hook in _hooks) {
      await hook.onBeforeStep(stepText, world);
    }
  }

  Future<void> afterStep(String stepText, WidgetTesterWorld world) async {
    for (final hook in _hooks) {
      await hook.onAfterStep(stepText, world);
    }
  }
}
