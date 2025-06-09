import 'dart:convert' show jsonDecode;
import 'package:flutter_gherkin_parser/integration_test_config.dart';
import 'package:flutter_gherkin_parser/lifecycle_manager.dart';
import 'package:flutter_gherkin_parser/models/models.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/steps/steps_registry.dart';
import 'package:flutter_gherkin_parser/bootstrap.dart';
import 'package:flutter_gherkin_parser/utils/terminal_colors.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

import 'package:flutter_test/flutter_test.dart';

bool _managersRegistered = false;

class IntegrationTestHelper {
  final IntegrationTestConfig config;
  final List<String> backgroundSteps;
  final Map<String, List<String>> scenariosAndSteps;

  late final LifecycleManager _hookManager;
  late final LifecycleManager _reporterManager;
  late final WidgetTesterWorld _world;

  FeatureInfo? _featureInfo;

  bool _skipRemaining = false;
  bool _errorOnBackground = false;
  bool _executedError = false;
  String _scenarioName = '';
  Object? _firstError;
  StackTrace? _firstStackTrace;

  void _registerGlobalHooks() {
    if (!_managersRegistered) {
      setUpAll(() async {
        await _hookManager.onBeforeAll();
        await _reporterManager.onBeforeAll();
      });

      tearDownAll(() async {
        await _hookManager.onAfterAll();
        await _reporterManager.onAfterAll();
      });

      _managersRegistered = true;
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
    _hookManager = LifecycleManager(config.hooks);
    _reporterManager = LifecycleManager(config.reporters);

    _world = WidgetTesterWorld();
    _world.setBinding(binding);

    StepsRegistry.resetToDefaults();
    StepsRegistry.addAll(config.steps);

    _registerGlobalHooks();
  }

  LifecycleManager get hookManager => _hookManager;

  LifecycleManager get reporterManger => _reporterManager;

  WidgetTesterWorld get world => _world;

  Future<void> setUpFeature({required FeatureInfo featureInfo}) async {
    await _hookManager.onFeatureStarted(featureInfo);
    await _reporterManager.onFeatureStarted(featureInfo);
    _featureInfo = featureInfo;
  }

  Future<void> setUp(WidgetTester tester, ScenarioInfo scenario) async {
    await _world.setTester(tester);

    await config.appLauncher.call(_world.tester);

    final steps = _parseStepsFromJsonList(backgroundSteps);

    if (steps.isNotEmpty) {
      for (final step in steps) {
        await _executeStep(step, true);
      }
    }
  }

  Future<void> runStepsForScenario(ScenarioInfo scenario) async {
    if (_skipRemaining && !_errorOnBackground) {
      _skipRemaining = false;
    }

    await _hookManager.onBeforeScenario(scenario);
    await _reporterManager.onBeforeScenario(scenario);

    final stepsJson = scenariosAndSteps[scenario.scenarioName] ?? <String>[];
    final steps = _parseStepsFromJsonList(stepsJson);

    for (final step in steps) {
      await _executeStep(step, false, scenario: scenario);
    }

    try {
      if (_executedError == false && _firstError != null) {
        _executedError = true;
        if (_firstStackTrace != null) {
          throw Error.throwWithStackTrace(_firstError!, _firstStackTrace!);
        } else {
          throw _firstError!;
        }
      }
    } catch (e, st) {
      await _handleTestError(e, st);
    } finally {
      await _hookManager.onAfterScenario(scenario.scenarioName);
      await _reporterManager.onAfterScenario(scenario.scenarioName);
    }
  }

  Future<void> _executeStep(Step step, bool isBackground, {ScenarioInfo? scenario}) async {
    final start = DateTime.now().microsecondsSinceEpoch;
    late StepResult result;
    await _hookManager.onBeforeStep(step.text, _world);
    await _reporterManager.onBeforeStep(step.text, world);

    final stepFunction = StepsRegistry.getStep(step.text);
    final raw = extractTableJson(step.text);
    GherkinTable? table;

    if (raw != null) {
      table = GherkinTable.fromJson(raw);
    }

    final tableRegex = RegExp(r'\s*"<<<[\s\S]*?>>>"\s*');
    final String stepText = step.text.replaceAll(tableRegex, ' ').trim();

    if (_skipRemaining) {
      final duration = DateTime.now().microsecondsSinceEpoch - start;

      result =  StepSkipped(
        stepText,
        step.line,
        duration,
        table: table,
      );

      print('$red➔ [${_featureInfo?.uri}:${step.line}] Skipping ${isBackground ? 'background step' : 'step'}: ${step.text}$reset');

      await _hookManager.onAfterStep(result, _world);
      await _reporterManager.onAfterStep(result, _world);

      return;
    }

    if (stepFunction != null) {
      try {
        print('$green➔ [${_featureInfo?.uri}:${step.line}] ${isBackground ? orange : yellow}Executing${isBackground ? ' background ' : ' '}step: ${step.text}$reset');
        await stepFunction(_world);

        final duration = DateTime.now().microsecondsSinceEpoch - start;
        result = StepSuccess(stepText, step.line, duration, table: table);
      } catch (e, st) {
        final duration = DateTime.now().microsecondsSinceEpoch - start;
        result =  StepFailure(
          stepText,
          step.line,
          duration,
          error: e,
          stackTrace: st,
          table: table,
        );
      }
    } else {
      final duration = DateTime.now().microsecondsSinceEpoch - start;
      final String error = 'Step not defined';
      print('${red}Step not defined: ${step.text}$reset');
      result = StepFailure(
        stepText,
        step.line,
        duration,
        error: error,
        table: table,
      );
    }

    await _hookManager.onAfterStep(result, _world);
    await _reporterManager.onAfterStep(result, _world);

    if (result is StepFailure) {
      _skipRemaining = true;
      _errorOnBackground = isBackground;

      if (!_errorOnBackground) {
        _scenarioName = scenario!.scenarioName;
      }

      if (result.stackTrace != null) {
        _firstError = result.error;
        _firstStackTrace =  result.stackTrace!;
      } else {
        _firstError = result.error;
      }
    }
  }

  String? extractTableJson(String stepText) {
    final tableRe = RegExp(r'<<<\s*(\{[\s\S]*?\})\s*>>>');
    final match = tableRe.firstMatch(stepText);
    return match?.group(1);
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
  ) async {
    print('${red}Error in ${_errorOnBackground ? 'background' : 'scenario "$_scenarioName"'}:\n$error.$reset');

    const blockedPrefixes = [
      'flutter_gherkin_parser',
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

    final String errorMessage = '${red}Error on step, skipping remaining steps for ${_errorOnBackground ? 'background' : 'scenario: "$_scenarioName"'}$reset';

    fail(errorMessage);
  }

  List<Step> _parseStepsFromJsonList(List<String> jsonList) {
    return jsonList.map((str) {
      final Map<String, dynamic> m = jsonDecode(str);
      return Step.fromJson(m);
    }).toList();
  }
}
