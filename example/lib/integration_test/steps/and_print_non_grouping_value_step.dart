import 'package:flutter_gherkin_parser/utils/step_definition_generic.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

StepDefinitionGeneric andPrintNonGroupingValue() {
  return generic1<String, WidgetTesterWorld>(
      'I check non-grouping(?: with this as param)?', (nonGrouping, context) async {
      print('Non-grouping value: "$nonGrouping"');
    },
  );
}

StepDefinitionGeneric andPrintNonGroupingValue3() {
  return generic3<String, String, String, WidgetTesterWorld>(
    'I print {string} or maybe this non-grouping(?: with this as param)? or this (one|two)', (value, nonGrouping, anotherValue, context) async {
      print('Normal value ${value} and Non-grouping value: "$nonGrouping" with $anotherValue');
    },
  );
}