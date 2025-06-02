import 'dart:io';
import 'package:flutter/foundation.dart' show ErrorDescription, FlutterError, FlutterErrorDetails;
import 'package:flutter_gherkin_parser/hooks/hook_manager.dart';
import 'package:flutter_gherkin_parser/integration_test_config.dart';
import 'package:flutter_gherkin_parser/steps/steps_registry.dart';
import 'package:flutter_gherkin_parser/utils/feature_parser.dart';
import 'package:flutter_gherkin_parser/utils/terminal_colors.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

import 'package:flutter_test/flutter_test.dart';

class IntegrationTestHelper {
  final IntegrationTestConfig config;
  late final HookManager _hookManager;
  late final WidgetTesterWorld _world;

  void init() {
    setUpAll(() async {
      await _hookManager.beforeAll();
    });

    tearDownAll(() async {
      await _hookManager.afterAll();
    });
  }

  IntegrationTestHelper(this.config) {
    _hookManager = HookManager(config.hooks);

    _world = WidgetTesterWorld();
    _world.initialize(onBindingInitialized: config.onBindingInitialized);

    init();
  }

  HookManager get hookManager => _hookManager;

  WidgetTesterWorld get world => _world;

  Future<void> runStepsForScenario(WidgetTester tester, String scenarioName, List<String> stepNames) async {
    await _world.setTester(tester);
    await _hookManager.beforeScenario(scenarioName);

    await _performScenario(
      run: () async {
        await config.appLauncher.call(_world.tester);
        for (final step in stepNames) {
          await _executeStep(step);
        }
      },
      after: () async {
        await performTestCleanup();
      },
      scenarioName: scenarioName,
    );

    await hookManager.afterScenario(scenarioName);
  }

  Future<void> _performScenario({
    required Future<void> Function() run,
    required Future<void> Function() after,
    required String scenarioName,
  }) async {
    try {
      await run();
    } catch (error, stackTrace) {
      await _handleTestError(error, stackTrace, scenarioName);
    } finally {
      await after();
    }
  }

  Future<void> _executeStep(String stepText) async {
    final Step step = Step(text: stepText);
    await _hookManager.beforeStep(step.text, _world);

    final stepFunction = StepsRegistry.getStep(step.text);
    if (stepFunction != null) {
      print('${yellow}Executing step: ${step.text}$reset');
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

      print('${green}Test cleanup and navigation completed.$reset');
    } catch (error) {
      print('${red}Failed during test cleanup: $error.$reset');
    }
  }

  Future<void> _handleTestError(dynamic error, StackTrace stackTrace, String scenarioName) async {
    print('${red}Error in scenario "$scenarioName": $error.$reset');

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription(
          'Error during integration test for scenario "$scenarioName"',
        ),
      ),
    );

    exit(1); // Exit with error code to indicate test failure
  }
}
