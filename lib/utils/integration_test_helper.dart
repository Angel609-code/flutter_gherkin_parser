import 'dart:convert' show jsonDecode;
import 'package:flutter_gherkin_parser/hooks/hook_manager.dart';
import 'package:flutter_gherkin_parser/integration_test_config.dart';
import 'package:flutter_gherkin_parser/models/step_model.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/steps/steps_registry.dart';
import 'package:flutter_gherkin_parser/utils/terminal_colors.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

import 'package:flutter_test/flutter_test.dart';

class IntegrationTestHelper {
  final IntegrationTestConfig config;
  final List<String> backgroundSteps;
  final Map<String, List<String>> scenariosAndSteps;
  final bool startRunningAllTests;

  late final HookManager _hookManager;
  late final WidgetTesterWorld _world;

  final String _scenarioNameKey = 'scenarioName';

  void init() {
    setUpAll(() async {
      await _hookManager.beforeAll();
    });

    tearDownAll(() async {
      await _hookManager.afterAll();
    });
  }

  IntegrationTestHelper({
    required this.config,
    this.scenariosAndSteps = const <String, List<String>>{},
    this.backgroundSteps = const <String>[],
    this.startRunningAllTests = false,
  }) {
    if (startRunningAllTests) {
      _hookManager = HookManager(config.hooks);

      init();
      return;
    }

    _hookManager = HookManager(config.hooks);

    _world = WidgetTesterWorld();
    _world.initialize(onBindingInitialized: config.onBindingInitialized);

    StepsRegistry.resetToDefaults();
    StepsRegistry.addAll(config.steps);

    if (config.runningSingleTest) {
      init();
    }
  }

  factory IntegrationTestHelper.runAllTest(IntegrationTestConfig config) => IntegrationTestHelper(
    config: config,
    startRunningAllTests: true,
  );

  HookManager get hookManager => _hookManager;

  WidgetTesterWorld get world => _world;

  Future<void> setUp(WidgetTester tester, String scenarioName) async {
    await _world.setTester(tester);
    _world.setAttachment(_scenarioNameKey, scenarioName);

    await config.appLauncher.call(_world.tester);

    final steps = _parseStepsFromJsonList(backgroundSteps);

    if (steps.isNotEmpty) {
      await _performScenarioOrBackground(
        run: () async {
          for (final step in steps) {
            await _executeStep(step, true);
          }
        },
        isBackground: true,
      );
    }
  }

  Future<void> runStepsForScenario() async {
    final String scenarioName = _world.getAttachment(_scenarioNameKey);
    await _hookManager.beforeScenario(scenarioName);

    final stepsJson = scenariosAndSteps[scenarioName] ?? <String>[];
    final steps = _parseStepsFromJsonList(stepsJson);

    await _performScenarioOrBackground(
      run: () async {
        for (final step in steps) {
          await _executeStep(step, false);
        }
      },
      after: () async {
        await performTestCleanup();
      },
      title: scenarioName,
    );

    await hookManager.afterScenario(scenarioName);
  }

  Future<void> _performScenarioOrBackground({
    required Future<void> Function() run,
    Future<void> Function()? after,
    String? title,
    bool isBackground = false
  }) async {
    try {
      await run();
    } catch (error, stackTrace) {
      await _handleTestError(error, stackTrace, title, isBackground);
    } finally {
      await after?.call();
    }
  }

  Future<void> _executeStep(Step step, bool isBackground) async {
    await _hookManager.beforeStep(step.text, _world);

    final stepFunction = StepsRegistry.getStep(step.text);

    StepResult result;
    if (stepFunction != null) {
      try {
        print('$green➔ [${step.source}] ${isBackground ? orange : yellow}Executing${isBackground ? ' background ' : ' '}step: ${step.text}$reset');
        await stepFunction(_world);
        result = StepSuccess(step.text);
        await _hookManager.afterStep(result, _world);
      } catch (e) {
        result = StepFailure(
          step.text,
          error: e,
          stackTrace: StackTrace.current,
        );
        await _hookManager.afterStep(result, _world);
        rethrow;
      }
    } else {
      final String error = 'Step not defined';
      print('${red}Step not defined: ${step.text}$reset');
      result = StepFailure(
        step.text,
        error: error,
        stackTrace: StackTrace.current,
      );
      await _hookManager.afterStep(result, _world);
      throw Exception(error);
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

    final String errorMessage = 'Error on step, skipping remaining steps for '
        '${isBackground ? 'background' : 'scenario: "$title"'}:\n'
        '  Cause: $error';

    fail(errorMessage);
  }

  List<Step> _parseStepsFromJsonList(List<String> jsonList) {
    return jsonList.map((str) {
      final Map<String, dynamic> m = jsonDecode(str);
      return Step.fromJson(m);
    }).toList();
  }
}
