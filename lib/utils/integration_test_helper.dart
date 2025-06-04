import 'dart:convert' show jsonDecode;
import 'dart:io';
import 'package:flutter/foundation.dart' show ErrorDescription, FlutterError, FlutterErrorDetails;
import 'package:flutter_gherkin_parser/hooks/hook_manager.dart';
import 'package:flutter_gherkin_parser/integration_test_config.dart';
import 'package:flutter_gherkin_parser/models/step_model.dart';
import 'package:flutter_gherkin_parser/steps/steps_registry.dart';
import 'package:flutter_gherkin_parser/utils/terminal_colors.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

import 'package:flutter_test/flutter_test.dart';

class IntegrationTestHelper {
  final IntegrationTestConfig config;
  final List<String> backgroundSteps;
  final Map<String, List<String>> scenariosAndSteps;

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
    required this.scenariosAndSteps,
    this.backgroundSteps = const <String>[]
  }) {
    _hookManager = HookManager(config.hooks);

    _world = WidgetTesterWorld();
    _world.initialize(onBindingInitialized: config.onBindingInitialized);

    StepsRegistry.resetToDefaults();
    StepsRegistry.addAll(config.steps);

    init();
  }

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
    if (stepFunction != null) {
      print('$green➔ [${step.source}] ${isBackground ? orange : yellow}Executing${isBackground ? ' background ' : ' '}step: ${step.text}$reset');
      await stepFunction(_world);
      await _hookManager.afterStep(step.text, _world);
    } else {
      print('${red}Step not defined: ${step.text}$reset');
      await _hookManager.afterStep(step.text, _world);
      exit(1);
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

  Future<void> _handleTestError(dynamic error, StackTrace stackTrace, String? title, bool isBackground) async {
    print('${red}Error in ${isBackground ? 'background' : 'scenario'}: $error.$reset');

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription(
          'Error during integration test for ${isBackground ? 'background' : 'scenario: "$title"'}',
        ),
      ),
    );

    exit(1); // Exit with error code to indicate test failure
  }

  List<Step> _parseStepsFromJsonList(List<String> jsonList) {
    return jsonList.map((str) {
      final Map<String, dynamic> m = jsonDecode(str);
      return Step.fromJson(m);
    }).toList();
  }
}
