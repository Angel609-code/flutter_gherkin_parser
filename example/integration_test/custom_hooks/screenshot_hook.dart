import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gherkin_parser/hooks/integration_hook.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

class ScreenshotHook extends IntegrationHook {
  @override
  Future<void> onBeforeStep(String stepText, WidgetTesterWorld world) async {
    try {
      if (kIsWeb) {
        throw 'Unsupported platform';
      } else if (Platform.isAndroid) {
        await world.binding.convertFlutterSurfaceToImage();
        await world.tester.pumpAndSettle();
        await world.binding.takeScreenshot('after-${stepText.hashCode}');
      }
    } catch (e) {
      debugPrint('There was an error taking screenshot $e');
    }
  }
}
