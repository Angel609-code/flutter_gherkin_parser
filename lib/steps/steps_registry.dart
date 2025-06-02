import 'package:flutter_gherkin_parser/steps/when_fill_field_step.dart';
import 'package:flutter_gherkin_parser/utils/step_definition_generic.dart';
import 'package:flutter_gherkin_parser/utils/steps_keywords.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

List<StepDefinitionGeneric> steps = [
  whenFillFieldStep(),
];

// Type definition for step functions
typedef StepFunction = Future<void> Function(WidgetTesterWorld);

// Registry for all step definitions
class StepsRegistry {
  static StepFunction? getStep(String stepText) {
    return (world) {
      final cleanedStepText = cleanStepText(stepText);

      for (StepDefinitionGeneric step in steps) {
        if (step.matches(cleanedStepText)) {
          return step.run(cleanedStepText, world);
        }
      }

      throw Exception('Step not defined or unmatched: $stepText');
    };
  }
}
