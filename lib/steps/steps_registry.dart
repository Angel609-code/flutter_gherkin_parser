import 'package:flutter_gherkin_parser/steps/when_fill_field_step.dart';
import 'package:flutter_gherkin_parser/utils/step_definition_generic.dart';
import 'package:flutter_gherkin_parser/utils/steps_keywords.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

/// Type definition for step functions
typedef StepFunction = Future<void> Function(WidgetTesterWorld);

class StepsRegistry {
  /// All built‐in steps shipped with the library.
  static final List<StepDefinitionGeneric> defaultSteps = [
    whenFillFieldStep(),
  ];

  /// The active list of steps. Starts as a copy of [defaultSteps].
  /// You can append additional steps by adding those in the IntegrationTestConfig.
  static List<StepDefinitionGeneric> steps = List.from(defaultSteps);

  /// Looks up a matching step by [stepText], or returns null if none found.
  static StepFunction? getStep(String stepText) {
    final cleanedStepText = cleanStepText(stepText);

    for (final stepDef in steps) {
      if (stepDef.matches(cleanedStepText)) {
        return (world) => stepDef.run(cleanedStepText, world);
      }
    }
    return null;
  }

  /// Append additional steps on top of existing ones:
  ///   StepsRegistry.addAll([stepA(), stepB()]);
  static void addAll(List<StepDefinitionGeneric> moreSteps) {
    steps.addAll(moreSteps);
  }

  /// Restore the active list back to the built‐in defaults.
  static void resetToDefaults() {
    steps = List.from(defaultSteps);
  }
}
