import 'package:flutter_gherkin_parser/utils/step_definition_generic.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';
import 'package:flutter_test/flutter_test.dart';

StepDefinitionGeneric thenReadTextStep() {
  return generic1<String, WidgetTesterWorld>(
    'I should see {string}', (text, context) async {
      final finder = find.text(text);
      expect(finder, findsOneWidget);
    },
  );
}
