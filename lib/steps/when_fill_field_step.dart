import 'package:flutter/material.dart';
import 'package:flutter_gherkin_parser/utils/step_definition_generic.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a step definition that enters [value] into the widget whose key is [key].
///
/// This uses `generic2` to define a step with two `{string}` parameters:
/// 1. The widget’s key (as a string)
/// 2. The text to enter (as a string)
///
/// Pattern example:
///   Then I fill the "email" field with "bob@gmail.com"
///   Then I fill the "name" field with "Woody Johnson"
///
/// How to build your own step:
/// 1. Choose the number of `{string}` parts and call the corresponding `genericN`:
///    - `generic1<T, W>(pattern, (arg1, world) async { … })`
///    - `generic2<T1, T2, W>(pattern, (arg1, arg2, world) async { … })`
///    - … up to `generic6`.
/// 2. In the pattern, use `{string}` wherever you expect a quoted string argument.
/// 3. Inside the closure, cast each `args[i] as Tn` and the `context` as your world type.
/// 4. Write test logic (e.g., find, expect, enterText, pump) using the `WidgetTesterWorld`.
///
/// Returns a `StepDefinitionGeneric` that the runner can register.
StepDefinitionGeneric whenFillFieldStep() {
  return generic2<String, String, WidgetTesterWorld>(
    'I fill the {string} field with {string}', (key, value, context) async {
      // Find the widget by its ValueKey.
      final finder = find.byKey(ValueKey(key));

      // Verify that exactly one widget matches.
      expect(finder, findsOneWidget);

      // Enter the provided text into the widget.
      await context.tester.enterText(finder, value);

      // Allow the UI to settle after text entry.
      await context.tester.pumpAndSettle();
    },
  );
}
