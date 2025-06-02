import 'package:example/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_gherkin_parser/integration_test_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'custom_hooks/debug_lifecycle_hook.dart';
import 'custom_hooks/screenshot_hook.dart';

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
);
