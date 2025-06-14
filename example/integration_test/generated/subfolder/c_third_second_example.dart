// DO NOT EDIT MANUALLY. Generated by flutter_gherkin_parser.
import '../../test_config.dart';
import 'package:flutter_gherkin_parser/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gherkin_parser/integration_test_helper.dart';

void main() async {
  final helper = IntegrationTestHelper(
    config: config,
    backgroundSteps: _backgroundSteps,
    scenariosAndSteps: _scenariosAndSteps,
  );

  group('Feature: Testing fail on background', () {
    setUpAll(() async {
      await helper.setUpFeature(featureInfo: _featureInfo);
    });

    testWidgets('Scenario: Second example of escenario', (WidgetTester tester) async {
      final ScenarioInfo scenario = ScenarioInfo(
        scenarioName: 'Second example of escenario',
        line: 7,
      );

      await helper.setUp(tester, scenario);
      await helper.runStepsForScenario(scenario);
    });
  });
}

FeatureInfo _featureInfo = FeatureInfo(
  featureName: 'Testing fail on background',
  uri: '/features/subfolder/c_third_second_example.feature',
  line: 1,
);

final List<String> _backgroundSteps = <String>[
  r'''{"text":"Given I have 5 items in category Books","line":5}''',
];

final Map<String, List<String>> _scenariosAndSteps = {
  'Second example of escenario': [
    r'''{"text":"And I fill the \"search\" field with \"Tofu\"","line":8}''',
    r'''{"text":"And I check non-grouping","line":9}''',
    r'''{"text":"Then I print \"hello\" or maybe this non-grouping with this as param or this two","line":10}''',
  ],
};
