import 'package:flutter_gherkin_parser/models/gherkin_table_model.dart';
import 'package:flutter_gherkin_parser/utils/step_definition_generic.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

StepDefinitionGeneric andPrintTable() {
  return generic1<GherkinTable, WidgetTesterWorld>(
    'I print table:',
        (table, context) async {
      print(table.toJson());
    },
  );
}