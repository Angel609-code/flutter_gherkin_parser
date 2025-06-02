import 'package:flutter_gherkin_parser/hooks/integration_hook.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

class DebugLifecycleHook extends IntegrationHook {
  @override
  int get priority => 100; // Run first

  @override
  Future<void> onBeforeAll() async {
    print('[DEBUG HOOK] 🟡 onBeforeAll');
  }

  @override
  Future<void> onAfterAll() async {
    print('[DEBUG HOOK] 🔴 onAfterAll');
  }

  @override
  Future<void> onBeforeScenario(String scenarioName) async {
    print('[DEBUG HOOK] 🟡 onBeforeScenario: $scenarioName');
  }

  @override
  Future<void> onAfterScenario(String scenarioName) async {
    print('[DEBUG HOOK] 🔵 onAfterScenario: $scenarioName');
  }

  @override
  Future<void> onBeforeStep(String stepText, WidgetTesterWorld world) async {
    print('[DEBUG HOOK] 🟡 onBeforeStep: $stepText');
  }

  @override
  Future<void> onAfterStep(String stepText, WidgetTesterWorld world) async {
    print('[DEBUG HOOK] 🟢 onAfterStep: $stepText');
  }
}
