import 'package:flutter_gherkin_parser/lifecycle_listener.dart';
import 'package:flutter_gherkin_parser/models/feature_model.dart';
import 'package:flutter_gherkin_parser/models/scenario_model.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

class LifecycleManager {
  final List<LifecycleListener> _listeners;

  LifecycleManager(List<LifecycleListener> listeners) : _listeners = [...listeners]..sort((a, b) => b.priority.compareTo(a.priority));

  Future<void> onBeforeAll() async {
    for (final listener in _listeners) {
      try {
        await listener.onBeforeAll();
      } catch (e, st) {
        print('🔴 Error in onBeforeAll: $e\n$st');
      }
    }
  }

  Future<void> onAfterAll() async {
    for (final listener in _listeners) {
      try {
        await listener.onAfterAll();
      } catch (e, st) {
        print('🔴 Error in onAfterAll: $e\n$st');
      }
    }
  }

  Future<void> onFeatureStarted(FeatureInfo feature) async {
    for (final listener in _listeners) {
      try {
        await listener.onFeatureStarted(feature);
      } catch (e, st) {
        print('🔴 Error in onFeatureStarted: $e\n$st');
      }
    }
  }

  Future<void> onBeforeScenario(ScenarioInfo scenario) async {
    for (final listener in _listeners) {
      try {
        await listener.onBeforeScenario(scenario);
      } catch (e, st) {
        print('🔴 Error in onBeforeScenario("${scenario.scenarioName}"): $e\n$st');
      }
    }
  }

  Future<void> onAfterScenario(String scenarioName) async {
    for (final listener in _listeners) {
      try {
        await listener.onAfterScenario(scenarioName);
      } catch (e, st) {
        print('🔴 Error in onAfterScenario("$scenarioName"): $e\n$st');
      }
    }
  }

  Future<void> onBeforeStep(String stepText, WidgetTesterWorld world) async {
    for (final listener in _listeners) {
      try {
        await listener.onBeforeStep(stepText, world);
      } catch (e, st) {
        print('🔴 Error in onBeforeStep("$stepText"): $e\n$st');
      }
    }
  }

  Future<void> onAfterStep(StepResult result, WidgetTesterWorld world) async {
    for (final listener in _listeners) {
      try {
        await listener.onAfterStep(result, world);
      } catch (e, st) {
        print('🔴 Error in onAfterStep("${result.stepText}"): $e\n$st');
      }
    }
  }
}
