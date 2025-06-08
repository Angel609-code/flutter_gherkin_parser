import 'package:flutter_gherkin_parser/integration_test_config.dart';
import 'package:integration_test/integration_test.dart';

IntegrationTestWidgetsFlutterBinding? _binding;
bool _bootstrapped = false;

/// Ensure the integration binding is initialized exactly once,
/// and invoke the config callback exactly once.
void bootstrap(IntegrationTestConfig config) {
  if (_bootstrapped) return;

  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  config.onBindingInitialized?.call(_binding!);

  _bootstrapped = true;
}

IntegrationTestWidgetsFlutterBinding get binding {
  if (_binding == null) {
    throw StateError(
        'You must call bootstrap(config) before accessing binding.'
    );
  }

  return _binding!;
}
