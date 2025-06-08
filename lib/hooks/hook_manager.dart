import 'package:flutter_gherkin_parser/hooks/integration_hook.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

class HookManager {
  final List<IntegrationHook> _hooks;

  HookManager(List<IntegrationHook> hooks) : _hooks = [...hooks]..sort((a, b) => b.priority.compareTo(a.priority));

  Future<void> onBeforeAll() async {
    for (final hook in _hooks) {
      try {
        await hook.onBeforeAll();
      } catch (e, st) {
        print('🔴 Error in onBeforeAll: $e\n$st');
      }
    }
  }

  Future<void> onAfterAll() async {
    for (final hook in _hooks) {
      try {
        await hook.onAfterAll();
      } catch (e, st) {
        print('🔴 Error in onAfterAll: $e\n$st');
      }
    }
  }

  Future<void> onBeforeScenario(String scenarioName) async {
    for (final hook in _hooks) {
      try {
        await hook.onBeforeScenario(scenarioName);
      } catch (e, st) {
        print('🔴 Error in onBeforeScenario("$scenarioName"): $e\n$st');
      }
    }
  }

  Future<void> onAfterScenario(String scenarioName) async {
    for (final hook in _hooks) {
      try {
        await hook.onAfterScenario(scenarioName);
      } catch (e, st) {
        print('🔴 Error in onAfterScenario("$scenarioName"): $e\n$st');
      }
    }
  }

  Future<void> onBeforeStep(String stepText, WidgetTesterWorld world) async {
    for (final hook in _hooks) {
      try {
        await hook.onBeforeStep(stepText, world);
      } catch (e, st) {
        print('🔴 Error in onBeforeStep("$stepText"): $e\n$st');
      }
    }
  }

  Future<void> onAfterStep(StepResult result, WidgetTesterWorld world) async {
    for (final hook in _hooks) {
      try {
        await hook.onAfterStep(result, world);
      } catch (e, st) {
        print('🔴 Error in onAfterStep("${result.stepText}"): $e\n$st');
      }
    }
  }
}
