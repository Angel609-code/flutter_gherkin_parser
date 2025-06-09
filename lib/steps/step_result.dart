import 'package:flutter_gherkin_parser/models/gherkin_table_model.dart';

abstract class StepResult {
  final String stepText;
  final int line;
  final int? duration;
  final GherkinTable? table;

  StepResult(this.stepText, this.line, this.duration, {this.table});
}

class StepSuccess extends StepResult {
  StepSuccess(super.stepText, super.line, super.duration, {super.table});
}

class StepSkipped extends StepResult {
  StepSkipped(super.stepText, super.line, super.duration, {super.table});
}

class StepFailure extends StepResult {
  final Object error;
  final StackTrace? stackTrace;

  StepFailure(
    super.stepText,
    super.line,
    super.duration, {
    required this.error,
    this.stackTrace,
    super.table,
  });
}
