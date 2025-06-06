import 'dart:convert';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_gherkin_parser/hooks/integration_hook.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';
import 'package:example/main.dart';

import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

class ScreenshotHook extends IntegrationHook {
  @override
  Future<void> onAfterStep(StepResult result, WidgetTesterWorld world) async {
    print('On after step for screenshot hook');
    if (result is StepFailure) {
      print('The on after step was an error taking an screenshot');
      try {
        await takeScreenshot(world.binding, world.tester, 'after-${result.stepText.hashCode}');
      } catch (e) {
        debugPrint('There was an error taking screenshot $e');
      }
    }
  }
}

Future<List<int>> takeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  if (kIsWeb) {
    await tester.pumpAndSettle();

    final boundary = MainApp.repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception(
        'Could not find a RenderRepaintBoundary using the provided key. '
            'Did you wrap your screen in a RepaintBoundary(key: boundaryKey)?',
      );
    }

    // Convert that boundary into an Image, then into PNG bytes.
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to convert screenshot to PNG bytes.');
    }

    final List<int> screenshotBytes = byteData.buffer.asUint8List();
    final String base64String = base64Encode(screenshotBytes);

    print('Screenshot "$name" as Base64:');
    // print(base64String);

    return screenshotBytes;
  }

  await binding.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();

  final List<int> screenshotBytes = await binding.takeScreenshot(name);
  final String base64String = base64Encode(screenshotBytes);

  print('Screenshot "$name" as Base64:');
  // print(base64String);

  return screenshotBytes;
}