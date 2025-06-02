import 'package:flutter_gherkin_parser/utils/placeholders.dart';
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

StepDefinitionGeneric generic<T1,W>(
    String pattern,
    Future<void> Function(W) fn,
    ) {
  final regex = RegExp('^${pattern.replaceAll('{string}', '"(.*?)"')}' r'$');
  return StepDefinitionGeneric(regex, 0, (args, context) => fn(context as W));
}

/// Creates a `StepDefinitionGeneric` for a pattern containing one placeholder.
///
/// The `pattern` string must include exactly one placeholder token in the form
/// `{token}`, where `token` corresponds to a key in [placeholders]. This helper
/// builds a single `RegExp` by replacing `{token}` with the associated `regexPart`.
/// When the step is matched at runtime, the captured text is passed to the
/// `parser` to produce a value of type `T1`. Finally, `fn` is invoked with that
/// parsed value and the world context of type `W`.
///
/// If the pattern does not contain exactly one placeholder, or if the placeholder
/// name is not registered in [placeholders], this function throws an `ArgumentError`.
///
/// Example:
/// ```dart
/// // To match: And I should see "Hello, world"
/// final step = generic1<String, WidgetTesterWorld>(
///   'I should see {string}',
///   (text, world) async {
///     expect(find.text(text), findsOneWidget);
///   },
/// );
/// ```
///
/// Type parameters:
/// - `T1`: The type returned by the placeholder’s parser (e.g. `String` or `GherkinTable`).
/// - `W`: The Gherkin world context (usually `WidgetTesterWorld`).
StepDefinitionGeneric generic1<T1, W>(
  String pattern,
  Future<void> Function(T1, W) fn,
) {
  final placeholderMatch = RegExp(r'\{(\w+)\}').firstMatch(pattern);
  if (placeholderMatch == null) {
    throw ArgumentError(
      'Pattern "$pattern" must contain exactly one placeholder, for example "{string}" or "{table}".',
    );
  }

  final token = placeholderMatch.group(1)!;
  final def = placeholders[token];
  if (def == null) {
    throw ArgumentError(
      'Unsupported placeholder "{$token}". Expected one of: ${placeholders.keys.join(', ')}.',
    );
  }

  final regexPattern = '^${pattern.replaceAll('{$token}', def.regexPart)}\$';
  final regex = RegExp(regexPattern);

  return StepDefinitionGeneric(regex, 1, (args, context) async {
      final rawValue = args[0].toString().trim();
      final parsed = def.parser(rawValue) as T1;
      return fn(parsed, context as W);
    },
  );
}

/// Creates a `StepDefinitionGeneric` for a pattern containing two placeholders.
///
/// The `pattern` must include exactly two placeholder tokens (for example,
/// `{string}` and `{table}`) in the order they appear in the step text. Each
/// placeholder name must match one of the keys in [placeholders]. The returned
/// `StepDefinitionGeneric` will:
///  • Match the entire step text against a single `RegExp` that replaces each
///    `{token}` with its `regexPart`.
///  • Capture exactly two groups (argCount = 2).
///  • Parse each captured group via the corresponding `parser` from [placeholders],
///    producing values of types `T1` and `T2`.
///  • Invoke `fn(parsed1, parsed2, world)` when the step is executed.
///
/// If `pattern` does not contain exactly two placeholders, or if any placeholder
/// name is not registered, an `ArgumentError` is thrown.
///
/// Type parameters:
///  • `T1`: The type returned by the first placeholder’s parser (for example, `String`).
///  • `T2`: The type returned by the second placeholder’s parser (for example, `GherkinTable`).
///  • `W`: The Gherkin world context (usually `WidgetTesterWorld`).
///
/// Example:
/// ```dart
/// // Matches: And I fill the "search" field with "Tofu"
/// final step = generic2<String, String, WidgetTesterWorld>(
///   'I fill the {string} field with {string}',
///   (fieldName, value, world) async {
///     final finder = find.byKey(ValueKey(fieldName));
///     expect(finder, findsOneWidget);
///     await world.tester.enterText(finder, value);
///     await world.tester.pumpAndSettle();
///   },
/// );
/// ```
StepDefinitionGeneric generic2<T1, T2, W>(
  String pattern,
  Future<void> Function(T1, T2, W) fn,
) {
  // Find all placeholder tokens in the pattern; expect exactly two.
  final allMatches = RegExp(r'\{(\w+)\}').allMatches(pattern).toList();
  if (allMatches.length != 2) {
    throw ArgumentError(
      'Pattern "$pattern" must contain exactly two placeholders, for example "{string}" and "{table}".',
    );
  }

  // Look up each placeholder’s definition in order.
  final defs = <PlaceholderDef>[];
  final regexBody = pattern.replaceAllMapped(
    RegExp(r'\{(\w+)\}'), (match) {
      final token = match.group(1)!;
      final def = placeholders[token];

      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$token}". Expected one of: ${placeholders.keys.join(', ')}.',
        );
      }

      defs.add(def);
      return def.regexPart;
    },
  );

  // Build a single RegExp that matches the entire step text.
  final regex = RegExp('^$regexBody\$');

  return StepDefinitionGeneric(regex, 2, (args, context) async {
      final raw1 = args[0].toString().trim();
      final raw2 = args[1].toString().trim();

      final parsed1 = defs[0].parser(raw1) as T1;
      final parsed2 = defs[1].parser(raw2) as T2;

      return fn(parsed1, parsed2, context as W);
    },
  );
}

/// Creates a `StepDefinitionGeneric` for a pattern containing three placeholders.
///
/// The `pattern` must include exactly three placeholder tokens in the order
/// they appear. Each token name must match a key in [placeholders]. This helper
/// constructs a single `RegExp` by replacing each `{token}` with its
/// `regexPart`. At runtime, it will:
///  • Capture three groups (argCount = 3).
///  • Parse each raw capture via the corresponding `parser`, resulting in
///    values of types `T1`, `T2`, and `T3`.
///  • Call `fn(parsed1, parsed2, parsed3, world)`.
///
/// Throws `ArgumentError` if the pattern does not contain exactly three
/// placeholders or if any placeholder is not registered.
///
/// Type parameters:
///  • `T1`, `T2`, `T3`: The types returned by the respective parsers.
///  • `W`: The Gherkin world context.
///
/// Example:
/// ```dart
/// // Matches: And I perform "{action}" on "{target}" with "{value}"
/// final step = generic3<String, String, String, WidgetTesterWorld>(
///   'I perform "{string}" on "{string}" with "{string}"',
///   (action, target, value, world) async {
///     // Implementation here...
///   },
/// );
/// ```
StepDefinitionGeneric generic3<T1, T2, T3, W>(
  String pattern,
  Future<void> Function(T1, T2, T3, W) fn,
) {
  final allMatches = RegExp(r'\{(\w+)\}').allMatches(pattern).toList();
  if (allMatches.length != 3) {
    throw ArgumentError(
      'Pattern "$pattern" must contain exactly three placeholders.',
    );
  }

  final defs = <PlaceholderDef>[];
  final regexBody = pattern.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),  (match) {
      final token = match.group(1)!;
      final def = placeholders[token];

      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$token}". Expected one of: ${placeholders.keys.join(', ')}.',
        );
      }

      defs.add(def);
      return def.regexPart;
    },
  );

  final regex = RegExp('^$regexBody\$');

  return StepDefinitionGeneric(regex, 3, (args, context) async {
      final raw1 = args[0].toString().trim();
      final raw2 = args[1].toString().trim();
      final raw3 = args[2].toString().trim();

      final parsed1 = defs[0].parser(raw1) as T1;
      final parsed2 = defs[1].parser(raw2) as T2;
      final parsed3 = defs[2].parser(raw3) as T3;

      return fn(parsed1, parsed2, parsed3, context as W);
    },
  );
}

/// Creates a `StepDefinitionGeneric` for a pattern containing four placeholders.
///
/// The `pattern` must contain exactly four `{token}` entries. Each token
/// must correspond to a key in [placeholders]. This function builds one
/// `RegExp` that matches the entire step, captures four groups, then parses
/// each group, yielding values of types `T1`, `T2`, `T3`, and `T4`.
/// Finally, it calls `fn(parsed1, parsed2, parsed3, parsed4, world)`.
///
/// Throws `ArgumentError` if the pattern does not have exactly four placeholders
/// or if any token is unregistered.
///
/// Type parameters:
///  • `T1`–`T4`: The types returned by each placeholder’s parser.
///  • `W`: The Gherkin world context.
///
/// Example:
/// ```dart
/// // Matches: And I compute "{x}" plus "{y}" to get "{result}" in "{context}"
/// final step = generic4<String, String, String, String, WidgetTesterWorld>(
///   'I compute "{string}" plus "{string}" to get "{string}" in "{string}"',
///   (x, y, result, ctx, world) async {
///     // Implementation here...
///   },
/// );
/// ```
StepDefinitionGeneric generic4<T1, T2, T3, T4, W>(
  String pattern,
  Future<void> Function(T1, T2, T3, T4, W) fn,
) {
  final allMatches = RegExp(r'\{(\w+)\}').allMatches(pattern).toList();
  if (allMatches.length != 4) {
    throw ArgumentError(
      'Pattern "$pattern" must contain exactly four placeholders.',
    );
  }

  final defs = <PlaceholderDef>[];
  final regexBody = pattern.replaceAllMapped(
    RegExp(r'\{(\w+)\}'), (match) {
      final token = match.group(1)!;
      final def = placeholders[token];

      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$token}". Expected one of: ${placeholders.keys.join(', ')}.',
        );
      }

      defs.add(def);
      return def.regexPart;
    },
  );

  final regex = RegExp('^$regexBody\$');

  return StepDefinitionGeneric(regex, 4, (args, context) async {
      final raw1 = args[0].toString().trim();
      final raw2 = args[1].toString().trim();
      final raw3 = args[2].toString().trim();
      final raw4 = args[3].toString().trim();

      final parsed1 = defs[0].parser(raw1) as T1;
      final parsed2 = defs[1].parser(raw2) as T2;
      final parsed3 = defs[2].parser(raw3) as T3;
      final parsed4 = defs[3].parser(raw4) as T4;

      return fn(parsed1, parsed2, parsed3, parsed4, context as W);
    },
  );
}

/// Creates a `StepDefinitionGeneric` for a pattern containing five placeholders.
///
/// The `pattern` must include exactly five `{token}` entries. Each token name
/// must be a key in [placeholders]. This helper:
///  • Builds one `RegExp` by replacing each `{token}` with its `regexPart`.
///  • Captures five groups at runtime (argCount = 5).
///  • Parses each captured string, producing five values of types `T1`–`T5`.
///  • Calls `fn(parsed1, parsed2, parsed3, parsed4, parsed5, world)`.
///
/// An `ArgumentError` is thrown if the pattern does not contain exactly five
/// placeholders or if any token is not registered.
///
/// Type parameters:
///  • `T1`–`T5`: The types returned by each parser in order.
///  • `W`: The Gherkin world context.
///
/// Example:
/// ```dart
/// // Matches: And I set "{key}" to "{value}" in "{section}" with "{mode}" and "{flag}"
/// final step = generic5<
///     String, String, String, String, String, WidgetTesterWorld>(
///   'I set "{string}" to "{string}" in "{string}" with "{string}" and "{string}"',
///   (key, value, section, mode, flag, world) async {
///     // Implementation here...
///   },
/// );
/// ```
StepDefinitionGeneric generic5<T1, T2, T3, T4, T5, W>(
  String pattern,
  Future<void> Function(T1, T2, T3, T4, T5, W) fn,
) {
  final allMatches = RegExp(r'\{(\w+)\}').allMatches(pattern).toList();
  if (allMatches.length != 5) {
    throw ArgumentError(
      'Pattern "$pattern" must contain exactly five placeholders.',
    );
  }

  final defs = <PlaceholderDef>[];
  final regexBody = pattern.replaceAllMapped(
    RegExp(r'\{(\w+)\}'), (match) {
      final token = match.group(1)!;
      final def = placeholders[token];
      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$token}". Expected one of: ${placeholders.keys.join(', ')}.',
        );
      }
      defs.add(def);
      return def.regexPart;
    },
  );

  final regex = RegExp('^$regexBody\$');

  return StepDefinitionGeneric(regex, 5, (args, context) async {
      final raw1 = args[0].toString().trim();
      final raw2 = args[1].toString().trim();
      final raw3 = args[2].toString().trim();
      final raw4 = args[3].toString().trim();
      final raw5 = args[4].toString().trim();

      final parsed1 = defs[0].parser(raw1) as T1;
      final parsed2 = defs[1].parser(raw2) as T2;
      final parsed3 = defs[2].parser(raw3) as T3;
      final parsed4 = defs[3].parser(raw4) as T4;
      final parsed5 = defs[4].parser(raw5) as T5;

      return fn(parsed1, parsed2, parsed3, parsed4, parsed5, context as W);
    },
  );
}

/// Creates a `StepDefinitionGeneric` for a pattern containing six placeholders.
///
/// The `pattern` must include exactly six `{token}` entries. Each placeholder
/// name must match a key in [placeholders]. This function:
///  • Replaces each `{token}` with its `regexPart` to form a single `RegExp`.
///  • Captures six groups at runtime (argCount = 6).
///  • Parses each captured string into types `T1`–`T6`.
///  • Invokes `fn(parsed1, parsed2, parsed3, parsed4, parsed5, parsed6, world)`.
///
/// An `ArgumentError` is thrown if the pattern does not have exactly six
/// placeholders or if any token is not registered in [placeholders].
///
/// Type parameters:
///  • `T1`–`T6`: The types returned by each parser, in order.
///  • `W`: The Gherkin world context.
///
/// Example:
/// ```dart
/// // Matches: And I verify "{a}" "{b}" "{c}" "{d}" "{e}" "{f}"
/// final step = generic6<
///     String, String, String, String, String, String, WidgetTesterWorld>(
///   'I verify "{string}" "{string}" "{string}" "{string}" "{string}" "{string}"',
///   (a, b, c, d, e, f, world) async {
///     // Implementation here...
///   },
/// );
/// ```
StepDefinitionGeneric generic6<T1, T2, T3, T4, T5, T6, W>(
  String pattern,
  Future<void> Function(T1, T2, T3, T4, T5, T6, W) fn,
) {
  final allMatches = RegExp(r'\{(\w+)\}').allMatches(pattern).toList();
  if (allMatches.length != 6) {
    throw ArgumentError(
      'Pattern "$pattern" must contain exactly six placeholders.',
    );
  }

  final defs = <PlaceholderDef>[];
  final regexBody = pattern.replaceAllMapped(
    RegExp(r'\{(\w+)\}'), (match) {
      final token = match.group(1)!;
      final def = placeholders[token];

      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$token}". Expected one of: ${placeholders.keys.join(', ')}.',
        );
      }

      defs.add(def);
      return def.regexPart;
    },
  );

  final regex = RegExp('^$regexBody\$');

  return StepDefinitionGeneric(regex, 6, (args, context) async {
      final raw1 = args[0].toString().trim();
      final raw2 = args[1].toString().trim();
      final raw3 = args[2].toString().trim();
      final raw4 = args[3].toString().trim();
      final raw5 = args[4].toString().trim();
      final raw6 = args[5].toString().trim();

      final parsed1 = defs[0].parser(raw1) as T1;
      final parsed2 = defs[1].parser(raw2) as T2;
      final parsed3 = defs[2].parser(raw3) as T3;
      final parsed4 = defs[3].parser(raw4) as T4;
      final parsed5 = defs[4].parser(raw5) as T5;
      final parsed6 = defs[5].parser(raw6) as T6;

      return fn(parsed1, parsed2, parsed3, parsed4, parsed5, parsed6, context as W);
    },
  );
}