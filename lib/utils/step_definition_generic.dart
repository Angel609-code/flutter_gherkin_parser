import 'package:flutter_gherkin_parser/world/widget_tester_world.dart';

class StepDefinitionGeneric {
  final RegExp pattern;
  final int argCount;
  final Future<void> Function(List<String>, WidgetTesterWorld) execute;

  StepDefinitionGeneric(this.pattern, this.argCount, this.execute);

  bool matches(String input) => pattern.hasMatch(input);

  Future<void> run(String input, WidgetTesterWorld context) async {
    final match = pattern.firstMatch(input);
    if (match == null) throw Exception('No match for: $input');

    final args = <String>[];
    for (int i = 1; i <= argCount; i++) {
      args.add(match.group(i) ?? '');
    }

    await execute(args, context);
  }
}

StepDefinitionGeneric generic1<T1,W>(
  String pattern,
  Future<void> Function(T1, W) fn,
) {
  final regex = RegExp('^${pattern.replaceAll('{string}', '"(.*?)"')}' r'$');
  return StepDefinitionGeneric(regex, 1, (args, context) => fn(args[0] as T1, context as W));
}

StepDefinitionGeneric generic2<T1, T2, W>(
  String pattern,
  Future<void> Function(T1, T2, W) fn,
) {
  final regex = RegExp('^${pattern.replaceAll('{string}', '"(.*?)"')}' r'$');
  return StepDefinitionGeneric(regex, 2, (args, context) => fn(args[0] as T1, args[1] as T2, context as W));
}

StepDefinitionGeneric generic3<T1, T2, T3, W>(
  String pattern,
  Future<void> Function(T1, T2, T3, W) fn,
) {
  final regex = RegExp('^${pattern.replaceAll('{string}', '"(.*?)"')}' r'$');
  return StepDefinitionGeneric(regex, 3, (args, context) => fn(args[0] as T1, args[1] as T2, args[2] as T3, context as W));
}

StepDefinitionGeneric generic4<T1, T2, T3, T4, W>(
  String pattern,
  Future<void> Function(T1, T2, T3, T4, W) fn,
) {
  final regex = RegExp('^${pattern.replaceAll('{string}', '"(.*?)"')}' r'$');
  return StepDefinitionGeneric(regex, 4, (args, context) => fn(args[0] as T1, args[1] as T2, args[2] as T3, args[3] as T4, context as W));
}

StepDefinitionGeneric generic5<T1, T2, T3, T4, T5, W>(
  String pattern,
  Future<void> Function(T1, T2, T3, T4, T5, W) fn,
) {
  final regex = RegExp('^${pattern.replaceAll('{string}', '"(.*?)"')}' r'$');
  return StepDefinitionGeneric(regex, 5, (args, context) => fn(args[0] as T1, args[1] as T2, args[2] as T3, args[3] as T4, args[4] as T5, context as W));
}

StepDefinitionGeneric generic6<T1, T2, T3, T4, T5, T6, W>(
  String pattern,
  Future<void> Function(T1, T2, T3, T4, T5, T6, W) fn,
) {
  final regex = RegExp('^${pattern.replaceAll('{string}', '"(.*?)"')}' r'$');
  return StepDefinitionGeneric(regex, 6, (args, context) => fn(args[0] as T1, args[1] as T2, args[2] as T3, args[3] as T4, args[4] as T5, args[5] as T6, context as W));
}
