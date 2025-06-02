import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Public API: this is all that test‐writers see.
/// It holds exactly:
///   • a reference to the current WidgetTester
///   • a reference to the IntegrationTest binding
///   • a key/value store for any custom data (attachments)
///
/// No lifecycle hooks (beforeScenario, beforeStep, etc.) live here.
/// Those belong in your HookManager or in user‐supplied Hook classes.
abstract class TestWorld {
  /// Called once (by the generated runner) as soon as `testWidgets(…)` begins.
  ///   • Implementers should call `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`
  ///    • Should capture/store the passed‐in WidgetTester if needed.
  Future<void> initialize();

  Future<void> setTester(WidgetTester tester);

  /// After initialize() has run, test‐writers can call `world.tester` to do
  /// pump/pumpAndSettle, find widgets, etc.
  WidgetTester get tester;

  /// After initialize() has run, test‐writers can call `world.binding` to
  /// take screenshots, convert FlutterSurface, etc.
  IntegrationTestWidgetsFlutterBinding get binding;

  /// A simple place to stash any shared data (keyed by String) during the run.
  void setAttachment<T>(String key, T value);

  /// Retrieve a previously‐stored attachment (or null).
  T? getAttachment<T>(String key);
}
