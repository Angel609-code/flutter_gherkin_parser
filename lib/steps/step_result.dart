/// Defines whether a step finished successfully or failed.
enum StepStatus {
  /// Indicates that a step ran without throwing any exception.
  passed,

  /// Indicates that a step threw an exception (or was not defined).
  failed,
}

/// The base class for any step execution result.  It always carries
/// the [stepText] that was attempted.
abstract class StepResult {
  /// The Gherkin step text (e.g. `"Given I am on the login screen"`).
  final String stepText;

  /// The constructor is protected because you should only instantiate
  /// one of the concrete subclasses: [StepSuccess] or [StepFailure].
  StepResult(this.stepText);
}

/// Represents a step that completed without error.
class StepSuccess extends StepResult {
  /// Create a [StepSuccess] for the given [stepText].
  StepSuccess(super.stepText);
}

/// Represents a step that threw an exception (or was undefined).
///
/// Carries an [error] object plus its [stackTrace].
class StepFailure extends StepResult {
  /// The exception (or any `Object`) thrown by the step function.
  final Object error;

  /// The stack trace corresponding to [error].
  final StackTrace? stackTrace;

  /// Create a [StepFailure] for the given [stepText].
  ///
  /// Both [error] and [stackTrace] are required to preserve debugging info.
  StepFailure(
    super.stepText, {
    required this.error,
    this.stackTrace,
  });
}
