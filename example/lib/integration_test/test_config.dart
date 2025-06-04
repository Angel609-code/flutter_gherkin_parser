// ignore_for_file: depend_on_referenced_packages
import 'package:example/integration_test/steps/and_enter_text_step.dart';
import 'package:example/integration_test/steps/and_print_non_grouping_value_step.dart';
import 'package:example/integration_test/steps/and_print_table_step.dart';
import 'package:example/integration_test/steps/when_click_in_step.dart';
import 'package:example/main.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_gherkin_parser/integration_test_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'custom_hooks/debug_lifecycle_hook.dart';
import 'custom_hooks/screenshot_hook.dart';
import 'steps/then_read_text_step.dart';

final config = IntegrationTestConfig(
  appLauncher: (WidgetTester tester) async {
    await tester.binding.reassembleApplication(); // Reinitialize app state
    await tester.pumpWidget(const MainApp());

    await tester.pumpAndSettle(); // Wait for UI to settle
  },
  onBindingInitialized: (IntegrationTestWidgetsFlutterBinding binding) async {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    debugPrint('Implement anything before the tests');
  },
  hooks: [
    DebugLifecycleHook(),
    ScreenshotHook(),
  ],
  steps: [
    thenReadTextStep(),
    andPrintTable(),
    whenClickWidgetStep(),
    andPrintNonGroupingValue(),
    andPrintNonGroupingValue3(),
    andEnterTextWithLookahead(),
    andHaveItemsInCategory(),
    andPrintWithOptionalHeightAndAge(),
    andMatchMultipleGroups(),
    andProcessMultilineText(),
    andProcessSixCaptures(),
  ]
);
