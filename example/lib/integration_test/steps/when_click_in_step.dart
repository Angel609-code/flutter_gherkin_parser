import 'package:flutter_gherkin_parser/utils/step_definition_generic.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

StepDefinitionGeneric whenClickWidgetStep() {
  return generic2<String, String, WidgetTesterWorld>(
    'I click in (text|input|dropdown) with key {string}', (type, key, context) async {
      print('this is the type: $type');

      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget);
      await context.tester.tap(finder);
      await context.tester.pumpAndSettle();
    },
  );
}
