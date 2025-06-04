import 'package:flutter_gherkin_parser/utils/step_definition_generic.dart';
import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

StepDefinitionGeneric andEnterTextWithLookahead() {
  return generic1<String, WidgetTesterWorld>(
    r'I enter "(.*?)"(?: into the search)', (text, world) async {
      print('Entered text: "$text"');
    },
  );
}

StepDefinitionGeneric andHaveItemsInCategory() {
  return generic2<String, String, WidgetTesterWorld>(
    r'I have (\d+) items? in category ([A-Za-z]+)', (count, category, world) async {
      print('Count: $count, Category: $category');
    },
  );
}

StepDefinitionGeneric andPrintWithOptionalHeightAndAge() {
  return generic3<String, String, String, WidgetTesterWorld>(
    r'I print (.+?)(?: with height (\d+)cm)? and age (\d+)', (name, height, age, world) async {
      print('Name: $name, Height: $height, Age: $age');
    },
  );
}

StepDefinitionGeneric andMatchMultipleGroups() {
  return generic4<String, String, String, String, WidgetTesterWorld>(
    r'I do (foo|bar) at position (\d+)(?: end) with code ([A-F0-9]{4}) and flag ([01])', (action, position, code, flag, world) async {
      print('Action: $action, Position: $position, Code: $code, Flag: $flag');
    },
  );
}

StepDefinitionGeneric andProcessMultilineText() {
  return generic5<String, String, String, String, String, WidgetTesterWorld>(
    r'I see text: ([\s\S]+?)END section (\w+), number (\d+), flag ([01]), type (urgent|normal)', (block, section, number, flag, type, world) async {
      print('Block: $block\nSection: $section, Number: $number, Flag: $flag, Type: $type');
    },
  );
}

StepDefinitionGeneric andProcessSixCaptures() {
  return generic6<String, String, String, String, String, String, WidgetTesterWorld>(
    r'I process (.+?) and (foo|bar) at (\d+)ms for code ([A-F0-9]{4}) with user "(.*?)" in group (\w+)', (first, choice, ms, code, user, group, world) async {
      print( 'First: $first, Choice: $choice, ms: $ms, Code: $code, User: $user, Group: $group');
    },
  );
}
