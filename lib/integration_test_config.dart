import 'package:flutter_gherkin_parser/hooks/integration_hook.dart';
import 'package:flutter_gherkin_parser/utils/step_definition_generic.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// A callback that always exposes its single argument as `binding`.
typedef PreBindingSetup = Future<void> Function(IntegrationTestWidgetsFlutterBinding binding);

/// A callback that takes the WidgetTester and must pump the user's app widget.
typedef AppLauncher = Future<void> Function(WidgetTester tester);

/// Defines the configuration used by the generated test runner.
///
/// You must provide this config from your `test_config.dart` file.
///
/// This is the main entry point for customizing integration tests.
class IntegrationTestConfig {
  /// Called immediately after `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`.
  /// The IDE will suggest the parameter name “binding” when you write the lambda.
  final PreBindingSetup? onBindingInitialized;

  /// REQUIRED: A callback that, given a WidgetTester, will pump the user’s app.
  final AppLauncher appLauncher;

  /// List of hooks that will be called during the test lifecycle.
  ///
  /// You can implement hooks for:
  /// - Seeding data
  /// - Cleaning up storage
  /// - Setting custom variables
  ///
  /// Hooks are composable and executed in order of descending [priority].
  final List<IntegrationHook> hooks;

  /// [Future Feature] Optional list of step definitions to override or extend the registry.
  ///
  /// Leave empty for now.
  final List<StepDefinitionGeneric> steps;

  /// A param that let know the hooks that is running a single test or more than one
  bool runningSingleTest = true;

  IntegrationTestConfig({
    required this.appLauncher,
    this.onBindingInitialized,
    this.hooks = const [],
    this.steps = const [],
  });
}
