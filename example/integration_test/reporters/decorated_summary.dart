import 'dart:math';
import 'package:wcwidth/wcwidth.dart';
import 'package:flutter_gherkin_parser/models/feature_model.dart';
import 'package:flutter_gherkin_parser/models/scenario_model.dart';
import 'package:flutter_gherkin_parser/reporters/integration_reporter.dart';
import 'package:flutter_gherkin_parser/steps/step_result.dart';
import 'package:flutter_gherkin_parser/utils/enums.dart';
import 'package:flutter_gherkin_parser/utils/terminal_colors.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

class DecoratedSummaryReporter extends IntegrationReporter {
  final _ansiEscape = RegExp(r'\x1B\[[0-9;]*m');
  DateTime? _startTime;
  int _totalScenarios = 0, _passedScenarios = 0, _failedScenarios = 0, _skippedScenarios = 0;
  ScenarioStatus? _currentStatus;

  @override
  int get priority => 0;

  @override
  Future<void> onBeforeAll() async => _startTime = DateTime.now();

  @override
  Future<void> onBeforeScenario(ScenarioInfo _) async {
    _totalScenarios++;
    _currentStatus = ScenarioStatus.passed;
  }

  @override
  Future<void> onAfterStep(StepResult result, WidgetTesterWorld _) async {
    if (result is StepFailure) {
      _currentStatus = ScenarioStatus.failed;
    } else if (result is StepSkipped && _currentStatus == ScenarioStatus.passed) {
      _currentStatus = ScenarioStatus.skipped;
    }
  }

  @override
  Future<void> onAfterScenario(String _) async {
    switch (_currentStatus) {
      case ScenarioStatus.passed:
        _passedScenarios++; break;
      case ScenarioStatus.failed:
        _failedScenarios++; break;
      case ScenarioStatus.skipped:
        _skippedScenarios++; break;
      default: break;
    }
  }

  int _visibleWidth(String s) => s.wcwidth();

  String _buildLine(String label, String value, int contentWidth, {String? symbol, String? colorCode}) {
    const reset = '\x1B[0m';
    final rawValue = symbol != null ? '$symbol$value' : value;
    final colored  = colorCode != null ? '$colorCode$rawValue$reset' : rawValue;
    final text     = '$label : $rawValue';
    final padSize  = contentWidth - _visibleWidth(text);
    final padding  = padSize > 0 ? ' ' * padSize : '';
    return '║ $label : $colored$padding ║';
  }

  @override
  Future<void> onAfterAll() async {
    final elapsed = DateTime.now().difference(_startTime!);
    final mins = elapsed.inMinutes, secs = elapsed.inSeconds % 60;
    final millis = (elapsed.inMilliseconds % 1000).toString().padLeft(3, '0');

    final entries = [
      ['Total scenarios', _totalScenarios.toString(), null, null],
      ['Passed',          _passedScenarios.toString(), '✓', green],
      ['Failed',          _failedScenarios.toString(),  '✗', red],
      ['Skipped',         _skippedScenarios.toString(), '↺', yellow],
      ['Elapsed Time',    '${mins}m${secs}.${millis}s', null, null],
    ];

    // Compute inner content width W
    final contentWidths = entries.map((e) {
      final label = e[0] as String;
      final val   = e[1] as String;
      final sym   = e[2] as String?;
      final raw   = sym != null ? '$sym$val' : val;
      return _visibleWidth('$label : $raw');
    });
    final W = contentWidths.reduce(max);

    // Border length = W + 2 (spaces)
    final border = '═' * (W + 2);
    const cyan  = '\x1B[96m';
    const reset = '\x1B[0m';

    // Header centered/padded to W
    final header = 'Summary'.padRight(W);

    final lines = [
      '╔$border╗',
      '║ $header ║',
      '╠$border╣',
      for (var e in entries)
        _buildLine(e[0] as String, e[1] as String, W,
            symbol: e[2] as String?, colorCode: e[3] as String?),
      '╚$border╝',
    ];

    final expected = W + 4;
    for (var raw in lines) {
      final noAnsi = raw.replaceAll(_ansiEscape, '');
      final actual = _visibleWidth(noAnsi);
      if (actual != expected) {
        print('DEBUG MISMATCH: got $actual, expected $expected → "$noAnsi"');
      }
    }

    print('');
    for (var l in lines) {
      print(l.replaceAllMapped(RegExp(r'^[╔╠╚║]'), (m) => '$cyan${m[0]}$reset'));
    }
    print(reset);
    print('');
  }

  @override Future<void> onBeforeStep(String _, WidgetTesterWorld __) async {}
  @override Future<void> onFeatureStarted(FeatureInfo _) async {}
  @override Map<String, dynamic> toJson() => {};
}
