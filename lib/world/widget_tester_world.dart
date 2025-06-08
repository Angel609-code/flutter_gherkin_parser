import 'dart:collection';
import 'package:flutter_gherkin_parser/world/test_world.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class WidgetTesterWorld implements TestWorld {
  late final IntegrationTestWidgetsFlutterBinding _binding;
  late WidgetTester _tester;

  final Map<String, Object> _attachments = HashMap();

  @override
  Future<void> setTester(WidgetTester tester) async {
    _tester = tester;
  }

  @override
  Future<void> setBinding(IntegrationTestWidgetsFlutterBinding binding) async {
    _binding = binding;
  }

  @override
  WidgetTester get tester => _tester;

  @override
  IntegrationTestWidgetsFlutterBinding get binding => _binding;

  @override
  void setAttachment<T>(String key, T value) {
    _attachments[key] = value as Object;
  }

  @override
  T? getAttachment<T>(String key) {
    final value = _attachments[key];
    if (value is T) return value;
    return null;
  }
}
