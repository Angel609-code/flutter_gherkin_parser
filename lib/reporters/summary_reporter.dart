import 'package:flutter_gherkin_parser/models/feature_model.dart';
import 'package:flutter_gherkin_parser/models/scenario_model.dart';
import 'package:flutter_gherkin_parser/reporters/integration_reporter.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/utils/enums.dart';
import 'package:flutter_gherkin_parser/utils/terminal_colors.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

class SummaryReporter extends IntegrationReporter {
  DateTime? _startTime;

  int _totalScenarios   = 0;
  int _passedScenarios  = 0;
  int _failedScenarios  = 0;
  int _skippedScenarios = 0;

  ScenarioStatus? _currentStatus;

  SummaryReporter();

  @override
  int get priority => 0;

  @override
  Future<void> onBeforeAll() async {
    _startTime = DateTime.now();
  }

  @override
  Future<void> onBeforeScenario(ScenarioInfo scenario) async {
    _totalScenarios++;
    _currentStatus = ScenarioStatus.passed;
  }

  @override
  Future<void> onAfterStep(StepResult result, WidgetTesterWorld world) async {
    if (result is StepFailure) {
      _currentStatus = ScenarioStatus.failed;
    } else if (result is StepSkipped) {
      if (_currentStatus == ScenarioStatus.passed) {
        _currentStatus = ScenarioStatus.skipped;
      }
    }
  }

  @override
  Future<void> onAfterScenario(String scenarioName) async {
    switch (_currentStatus) {
      case ScenarioStatus.passed:
        _passedScenarios++;
        break;
      case ScenarioStatus.failed:
        _failedScenarios++;
        break;
      case ScenarioStatus.skipped:
        _skippedScenarios++;
        break;
      default:
        break;
    }
  }

  @override
  Future<void> onAfterAll() async {
    final elapsed = DateTime.now().difference(_startTime!);
    final mins   = elapsed.inMinutes;
    final secs   = elapsed.inSeconds % 60;
    final millis = (elapsed.inMilliseconds % 1000).toString().padLeft(3, '0');

    print('');
    print(
        '$_totalScenarios scenarios ' +
            '(${green}$_passedScenarios passed$reset, ' +
            '${red}$_failedScenarios failed$reset, ' +
            '${yellow}$_skippedScenarios skipped$reset)'
    );
    print('${mins}m${secs}.${millis}s');
    print('');
  }

  @override Map<String, dynamic> toJson() => {};
  @override Future<void> onBeforeStep(String _, WidgetTesterWorld __) async {}
  @override Future<void> onFeatureStarted(FeatureInfo _) async {}
}
