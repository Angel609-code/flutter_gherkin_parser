import 'dart:collection';
import 'package:flutter_gherkin_parser/integration_test_config.dart';
import 'package:flutter_gherkin_parser/world/test_world.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Concrete, library‐internal implementation of [TestWorld].
/// Wires up:
///   • IntegrationTestWidgetsFlutterBinding.ensureInitialized()
///   • WidgetTester (passed in from testWidgets)
///   • A private attachments map for any custom data
///
/// Do not re‐export this class in your package’s public API—users should code against [TestWorld].
class WidgetTesterWorld implements TestWorld {
  late final IntegrationTestWidgetsFlutterBinding _binding;
  late WidgetTester _tester;

  final Map<String, Object> _attachments = HashMap();

  @override
  Future<void> initialize({PreBindingSetup? onBindingInitialized}) async {
    // Ensure the integration‐test binding is initialized exactly once:
    _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    onBindingInitialized?.call(_binding);
  }

  @override
  Future<void> setTester(WidgetTester tester) async {
    _tester = tester;
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
