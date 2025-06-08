import 'dart:convert' show jsonDecode;
import 'package:flutter_gherkin_parser/hooks/hook_manager.dart';
import 'package:flutter_gherkin_parser/integration_test_config.dart';
import 'package:flutter_gherkin_parser/models/step_model.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/steps/steps_registry.dart';
import 'package:flutter_gherkin_parser/utils/bootstrap.dart';
import 'package:flutter_gherkin_parser/utils/terminal_colors.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

import 'package:flutter_test/flutter_test.dart';

bool _hooksRegistered = false;

class IntegrationTestHelper {
  final IntegrationTestConfig config;
  final List<String> backgroundSteps;
  final Map<String, List<String>> scenariosAndSteps;

  late final HookManager _hookManager;
  late final WidgetTesterWorld _world;

  final String _scenarioNameKey = 'scenarioName';

  void _registerGlobalHooks() {
    if (!_hooksRegistered) {
      setUpAll(() => _hookManager.onBeforeAll());
      tearDownAll(() => _hookManager.onAfterAll());
      _hooksRegistered = true;
    }
  }

  factory IntegrationTestHelper({
    required IntegrationTestConfig config,
    Map<String,List<String>> scenariosAndSteps = const {},
    List<String> backgroundSteps = const [],
  }) {
    bootstrap(config);
    return IntegrationTestHelper._(config, scenariosAndSteps, backgroundSteps);
  }

  IntegrationTestHelper._(this.config, this.scenariosAndSteps, this.backgroundSteps) {
    _hookManager = HookManager(config.hooks);
    _world = WidgetTesterWorld();
    _world.setBinding(binding);

    StepsRegistry.resetToDefaults();
    StepsRegistry.addAll(config.steps);

    _registerGlobalHooks();
  }

  HookManager get hookManager => _hookManager;

  WidgetTesterWorld get world => _world;

  Future<void> setUp(WidgetTester tester, String scenarioName) async {
    await _world.setTester(tester);
    _world.setAttachment(_scenarioNameKey, scenarioName);

    await config.appLauncher.call(_world.tester);

    final steps = _parseStepsFromJsonList(backgroundSteps);

    if (steps.isNotEmpty) {
      try {
        for (final step in steps) {
          final StepResult result = await _executeStep(step, false);
          await _hookManager.onAfterStep(result, _world);

          if (result is StepFailure) {
            if (result.stackTrace != null) {
              throw Error.throwWithStackTrace(result.error, result.stackTrace!);
            } else {
              throw result.error;
            }
          }
        }
      } catch (error, stackTrace) {
        await _handleTestError(error, stackTrace, scenarioName, true);
      }
    }
  }

  Future<void> runStepsForScenario() async {
    final String scenarioName = _world.getAttachment(_scenarioNameKey);
    await _hookManager.onBeforeScenario(scenarioName);

    final stepsJson = scenariosAndSteps[scenarioName] ?? <String>[];
    final steps = _parseStepsFromJsonList(stepsJson);
    try {
      for (final step in steps) {
        final StepResult result = await _executeStep(step, false);
        await _hookManager.onAfterStep(result, _world);

        if (result is StepFailure) {
          if (result.stackTrace != null) {
            throw Error.throwWithStackTrace(result.error, result.stackTrace!);
          } else {
            throw result.error;
          }
        }
      }
    } catch (error, stackTrace) {
      await _handleTestError(error, stackTrace, scenarioName, false);
    }

    await hookManager.onAfterScenario(scenarioName);
  }

  Future<StepResult> _executeStep(Step step, bool isBackground) async {
    await _hookManager.onBeforeStep(step.text, _world);

    final stepFunction = StepsRegistry.getStep(step.text);

    if (stepFunction != null) {
      try {
        print('$green➔ [${step.source}] ${isBackground ? orange : yellow}Executing${isBackground ? ' background ' : ' '}step: ${step.text}$reset');
        await stepFunction(_world);

        return StepSuccess(step.text);
      } catch (e, st) {
        return StepFailure(
          step.text,
          error: e,
          stackTrace: st,
        );
      }
    } else {
      final String error = 'Step not defined';
      print('${red}Step not defined: ${step.text}$reset');
      return StepFailure(
        step.text,
        error: error,
      );
    }
  }

  Future<void> performTestCleanup() async {
    try {
      _world.binding.reset();
      _world.binding.resetEpoch();
      _world.binding.resetFirstFrameSent();

      print('${green}Test cleanup completed.$reset');
    } catch (error) {
      print('${red}Failed during test cleanup: $error.$reset');
    }
  }

  Future<void> _handleTestError(
    Object error,
    StackTrace stackTrace,
    String? title,
    bool isBackground,
  ) async {
    print('${red}Error in ${isBackground ? 'background' : 'scenario "$title"'}:\n$error.$reset');

    const blockedPrefixes = [
      'packages/flutter_gherkin_parser/',
    ];

    final lines = stackTrace.toString().trim().split('\n');
    final lastByFile = <String, String>{};

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.contains('package') && !blockedPrefixes.any((prefix) => trimmed.contains(prefix))) {
        final match = RegExp(r'^(.*\.dart)').firstMatch(trimmed);
        if (match != null) {
          final file = match.group(1)!;
          lastByFile[file] = line;
        }
      }
    }

    for (final line in lastByFile.values) {
      print('${red}$line$reset');
    }

    final String errorMessage = '${red}Error on step, skipping remaining steps for ${isBackground ? 'background' : 'scenario: "$title"'}$reset';

    print(errorMessage);
  }

  List<Step> _parseStepsFromJsonList(List<String> jsonList) {
    return jsonList.map((str) {
      final Map<String, dynamic> m = jsonDecode(str);
      return Step.fromJson(m);
    }).toList();
  }
}
