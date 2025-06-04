import 'package:flutter_gherkin_parser/utils/capture_token.dart';
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

/// Defines a step with exactly one capture in [rawPattern]. That capture may be:
///  • A placeholder `{string}`, `{table}`, etc.
///  • A manual regex group `(text|input|dropdown)` (excluding `(?:…)`)
///
/// The single capture’s position in [rawPattern] determines the single argument
/// passed to [fn]. Throws [ArgumentError] if the total count of placeholders +
/// manual groups ≠ 1.
///
/// Example:
/// ```dart
/// // One placeholder
/// generic1<String, WidgetTesterWorld>(
///   'I should see {string}',
///   (text, world) async { /* … */ },
/// );
///
/// // One manual group
/// generic1<String, WidgetTesterWorld>(
///   'I tap on (button|link)',
///   (elemType, world) async { /* elemType is "button" or "link" */ },
/// );
/// ```
StepDefinitionGeneric generic1<T, W>(
  String rawPattern,
  Future<void> Function(T value, W world) fn,
) {
  // Rewrite any optional non-capturing group "(?: …)?"
  //    into "(…)?", so it becomes a single capturing group.
  rawPattern = rawPattern.replaceAllMapped(
    // Capture exactly the leading space plus everything until ")"
    RegExp(r'\(\?:(\s[^)]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  // Count placeholders in rawPattern
  final placeholderMatches = RegExp(r'\{(\w+)\}').allMatches(rawPattern).toList();
  final placeholderCount = placeholderMatches.length;

  // Count manual capture groups "(…)" in rawPattern, ignoring "(?:…)"
  final manualPositions = <int>[];
  final openParRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanForManual = 0;

  while (true) {
    final m = openParRegex.firstMatch(rawPattern.substring(scanForManual));

    if (m == null) break;

    final pos = scanForManual + m.start;
    manualPositions.add(pos);
    scanForManual = pos + 1;
  }

  final manualCount = manualPositions.length;

  // Ensure exactly one total capture
  if (placeholderCount + manualCount != 1) {
    throw ArgumentError(
      'generic1 requires exactly one capture (placeholder or manual group). '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  // If there is one placeholder, replace it with its regex and record its def
  final placeholderDefs = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),  (match) {
      final name = match.group(1)!;
      final def = placeholders[name];

      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$name}". Supported: ${placeholders.keys.join(", ")}.',
        );
      }

      placeholderDefs.add(def);
      return def.regexPart;
    },
  );

  // If there is one manual group, extract its inner pattern
  final manualDefs = <String>[];
  final manualGroupRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanIndex = 0;

  while (true) {
    final m = manualGroupRegex.firstMatch(regexBody.substring(scanIndex));

    if (m == null) break;

    final start = scanIndex + m.start;
    var depth = 1;
    var i = start + 1;

    while (i < regexBody.length && depth > 0) {
      if (regexBody[i] == '(') {
        depth++;
      } else if (regexBody[i] == ')') {
        depth--;
      }

      i++;
    }

    final inner = regexBody.substring(start + 1, i - 1);
    manualDefs.add(inner);
    scanIndex = i;
  }

  // Determine which token appears (placeholder vs. manual) and record order
  final ordered = <CaptureToken>[];
  var pIndex = 0, mIndex = 0;
  var idx = 0;

  while (idx < rawPattern.length) {
    final phMatch = RegExp(r'\{(\w+)\}').matchAsPrefix(rawPattern, idx);
    final opMatch = RegExp(r'\(').matchAsPrefix(rawPattern, idx);

    if (phMatch != null) {
      ordered.add(CaptureToken.fromPlaceholder(placeholderDefs[pIndex++]));
      idx += phMatch.group(0)!.length;
    } else if (opMatch != null) {
      if (rawPattern.substring(idx).startsWith('(?:')) {
        idx += 3;
      } else {
        ordered.add(CaptureToken.fromManual(manualDefs[mIndex++]));
        idx += 1;
      }
    } else {
      idx++;
    }
  }

  // Verify final regex has exactly one capture group
  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?:').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;

  if (groupCount != 1 || ordered.length != 1) {
    throw ArgumentError(
      'generic1 expects exactly one capturing group after replacement. '
          'Found $groupCount in regex:\n'
          '  $regexBody',
    );
  }

  // Build the anchored regex
  final finalRegex = RegExp('^$regexBody\$');

  return StepDefinitionGeneric(finalRegex, 1, (args, context) async {
    final raw = args[0];
    final token = ordered[0];
    final parsedValue = (token.kind == CaptureKind.placeholder)
        ? token.placeholderDef!.parser(raw)
        : raw;

    await fn(parsedValue as T, context as W);
  });
}

/// Defines a step with exactly two captures in [rawPattern].
/// Each capture may be either:
///  • A placeholder (`{string}`, `{table}`, etc.)
///  • A manual group (`(text|input|dropdown)`, excluding `(?:…)`)
///
/// The left-to-right order of these two captures in [rawPattern]
/// determines the argument order passed to [fn]. Throws [ArgumentError]
/// if the total number of placeholders + manual groups ≠ 2.
///
/// Example:
/// ```dart
/// // One manual capture + one placeholder
/// generic2<String, String, WidgetTesterWorld>(
///   'I click in (text|input|dropdown) with key {string}',
///   (type, key, world) async { /* … */ },
/// );
///
/// // Two placeholders
/// generic2<String, String, WidgetTesterWorld>(
///   'I compare {string} with {string}',
///   (first, second, world) async { /* … */ },
/// );
///
/// // Two manual groups
/// generic2<String, String, WidgetTesterWorld>(
///   'I choose (mouse|keyboard) and (Linux|Windows)',
///   (a, b, world) async { /* … */ },
/// );
/// ```
StepDefinitionGeneric generic2<T1, T2, W>(
  String rawPattern,
  Future<void> Function(T1, T2, W world) fn,
) {
  // Rewrite any optional non-capturing group "(?: …)?"
  //    into "(…)?", so it becomes a single capturing group.
  rawPattern = rawPattern.replaceAllMapped(
    // Capture exactly the leading space plus everything until ")"
    RegExp(r'\(\?:(\s[^)]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  // Count placeholders in rawPattern.
  final placeholderMatches = RegExp(r'\{(\w+)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  // Count manual capturing groups "(…)" in rawPattern, ignoring "(?:…)".
  final manualMatches = <int>[];
  final openParRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanIndexForManual = 0;

  while (true) {
    final m = openParRegex.firstMatch(rawPattern.substring(scanIndexForManual));
    if (m == null) break;
    final start = scanIndexForManual + m.start;
    manualMatches.add(start);
    scanIndexForManual = start + 1;
  }

  final manualCount = manualMatches.length;

  // Validate there are exactly two total captures before doing any replacements.
  if (placeholderCount + manualCount != 2) {
    throw ArgumentError(
      'generic2 requires exactly two captures '
          '(sum of placeholders and manual groups). '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in pattern:\n'
          '  $rawPattern',
    );
  }

  // Replace each placeholder "{token}" with its regex fragment,
  // collecting the associated PlaceholderDef objects in order.
  final placeholderTokens = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
  RegExp(r'\{(\w+)\}'), (match) {
      final tokenName = match.group(1)!;
      final placeholderDef = placeholders[tokenName];
      if (placeholderDef == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$tokenName}". '
              'Supported tokens: ${placeholders.keys.join(", ")}.',
        );
      }

      placeholderTokens.add(placeholderDef);
      return placeholderDef.regexPart;
    },
  );

  // Locate each manual capturing group "(…)" in regexBody (ignoring "(?:…)")
  // and store its inner text in manualTokens. We scan one-by-one to match parentheses.
  final manualTokens = <String>[];
  final manualGroupRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanIndex = 0;

  while (true) {
    final m = manualGroupRegex.firstMatch(regexBody.substring(scanIndex));
    if (m == null) break;
    final start = scanIndex + m.start;

    // Find the matching closing parenthesis for this capturing group.
    var depth = 1;
    var i = start + 1;
    while (i < regexBody.length && depth > 0) {
      if (regexBody[i] == '(') {
        depth++;
      } else if (regexBody[i] == ')') {
        depth--;
      }

      i++;
    }

    // Extract the substring inside the parentheses (excluding "(" and ")").
    final inner = regexBody.substring(start + 1, i - 1);
    manualTokens.add(inner);
    scanIndex = i;
  }

  // Determine the order in which placeholders and manual groups appear
  // in the original rawPattern. We walk rawPattern left-to-right and
  // push each encountered capture into orderedCaptures.
  final orderedCaptures = <CaptureToken>[];
  var placeholderIndex = 0;
  var manualIndex = 0;
  var idx = 0;

  while (idx < rawPattern.length) {
    final placeholderMatch = RegExp(r'\{(\w+)\}').matchAsPrefix(rawPattern, idx);
    final openParMatch = RegExp(r'\(').matchAsPrefix(rawPattern, idx);

    if (placeholderMatch != null) {
      orderedCaptures.add(
        CaptureToken.fromPlaceholder(placeholderTokens[placeholderIndex++]),
      );
      idx += placeholderMatch.group(0)!.length;
    } else if (openParMatch != null) {
      // If it starts with "(?:", skip those three characters.
      if (rawPattern.substring(idx).startsWith('(?:')) {
        idx += 3;
      } else {
        // This is a manual capturing group
        orderedCaptures.add(
          CaptureToken.fromManual(manualTokens[manualIndex++]),
        );
        idx += 1; // move past "("
      }
    } else {
      idx++;
    }
  }

  // After replacing placeholders, count total "(" in regexBody minus "(?:"
  // to get the actual number of capture groups in the final regex.
  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?:').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;

  // Double-check that the final regex has exactly two groups. If not, throw.
  if (groupCount != 2 || orderedCaptures.length != 2) {
    throw ArgumentError(
      'generic2 expects exactly two capturing groups after placeholder replacement. '
          'Found $groupCount groups in generated regex:\n'
          '  $regexBody',
    );
  }

  // Build the final anchored regex.
  final finalRegex = RegExp('^$regexBody\$');

  // Return a StepDefinitionGeneric that will extract exactly two arguments.
  return StepDefinitionGeneric(finalRegex, 2, (args, context) async {
    final parsed = <dynamic>[];

    // For each capture in left-to-right order, apply the correct parser.
    for (var i = 0; i < 2; i++) {
      final rawText = args[i].toString();
      final token = orderedCaptures[i];

      if (token.kind == CaptureKind.placeholder) {
        // Use the placeholder’s parser (e.g. strip quotes, parse JSON).
        parsed.add(token.placeholderDef!.parser(rawText));
      } else {
        // Manual capture: return the raw string directly.
        parsed.add(rawText);
      }
    }

    // Cast the two parsed values to T1 and T2, then invoke the callback.
    final firstArg = parsed[0] as T1;
    final secondArg = parsed[1] as T2;

    await fn(firstArg, secondArg, context as W);
  });
}

/// Defines a step that expects exactly three captures in [rawPattern].
/// Each capture may be either:
///  • A placeholder `{string}`, `{table}`, etc.
///  • A manual regex group `(home|work|office)` (excluding `(?:…)`).
///
/// The order in which these three captures appear in [rawPattern]
/// determines the argument order passed to [fn].
///
/// If the combined number of placeholders and manual groups is not exactly three,
/// this method throws an [ArgumentError] immediately.
StepDefinitionGeneric generic3<T1, T2, T3, W>(
  String rawPattern,
  Future<void> Function(T1, T2, T3, W world) fn,
) {
  // Rewrite any optional non-capturing group "(?: …)?"
  //    into "(…)?", so it becomes a single capturing group.
  rawPattern = rawPattern.replaceAllMapped(
    // Capture exactly the leading space plus everything until ")"
    RegExp(r'\(\?:(\s[^)]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  final placeholderMatches = RegExp(r'\{(\w+)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  final manualPositions = <int>[];
  final openParRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanForManual = 0;

  while (true) {
    final m = openParRegex.firstMatch(rawPattern.substring(scanForManual));

    if (m == null) break;

    final pos = scanForManual + m.start;
    manualPositions.add(pos);
    scanForManual = pos + 1;
  }

  final manualCount = manualPositions.length;

  if (placeholderCount + manualCount != 3) {
    throw ArgumentError(
      'generic3 requires exactly three captures '
          '(sum of placeholders and manual groups). '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  final placeholderDefs = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{(\w+)\}'), (match) {
      final name = match.group(1)!;
      final def = placeholders[name];

      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$name}". Supported: ${placeholders.keys.join(", ")}.',
        );
      }

      placeholderDefs.add(def);
      return def.regexPart;
    },
  );

  final manualDefs = <String>[];
  final manualGroupRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanIndex = 0;

  while (true) {
    final m = manualGroupRegex.firstMatch(regexBody.substring(scanIndex));
    if (m == null) break;
    final start = scanIndex + m.start;
    var depth = 1;
    var i = start + 1;

    while (i < regexBody.length && depth > 0) {
      if (regexBody[i] == '(') {
        depth++;
      }
      else if (regexBody[i] == ')') {
        depth--;
      }

      i++;
    }
    final inner = regexBody.substring(start + 1, i - 1);
    manualDefs.add(inner);
    scanIndex = i;
  }

  final ordered = <CaptureToken>[];
  var pIndex = 0, mIndex = 0;
  var idx = 0;

  while (idx < rawPattern.length) {
    final ph = RegExp(r'\{(\w+)\}').matchAsPrefix(rawPattern, idx);
    final op = RegExp(r'\(').matchAsPrefix(rawPattern, idx);

    if (ph != null) {
      ordered.add(CaptureToken.fromPlaceholder(placeholderDefs[pIndex++]));
      idx += ph.group(0)!.length;
    } else if (op != null) {
      if (rawPattern.substring(idx).startsWith('(?:')) {
        idx += 3;
      } else {
        ordered.add(CaptureToken.fromManual(manualDefs[mIndex++]));
        idx += 1;
      }
    } else {
      idx++;
    }
  }

  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?:').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;

  if (groupCount != 3 || ordered.length != 3) {
    throw ArgumentError(
      'generic3 expects exactly three capturing groups after replacement. '
          'Found $groupCount in regex:\n'
          '  $regexBody',
    );
  }

  final finalRegex = RegExp('^$regexBody\$');

  return StepDefinitionGeneric(finalRegex, 3, (args, context) async {
    final parsed = <dynamic>[];
    for (var i = 0; i < 3; i++) {
      final raw = args[i].toString();
      final token = ordered[i];

      if (token.kind == CaptureKind.placeholder) {
        parsed.add(token.placeholderDef!.parser(raw));
      } else {
        parsed.add(raw);
      }
    }

    final a = parsed[0] as T1;
    final b = parsed[1] as T2;
    final c = parsed[2] as T3;

    await fn(a, b, c, context as W);
  });
}

/// Defines a step that expects exactly four captures in [rawPattern].
/// Each capture may be a placeholder or a manual regex group.
/// Throws [ArgumentError] if the total count of captures is not four.
StepDefinitionGeneric generic4<T1, T2, T3, T4, W>(
  String rawPattern,
  Future<void> Function(T1, T2, T3, T4, W world) fn,
) {
  // Rewrite any optional non-capturing group "(?: …)?"
  //    into "(…)?", so it becomes a single capturing group.
  rawPattern = rawPattern.replaceAllMapped(
    // Capture exactly the leading space plus everything until ")"
    RegExp(r'\(\?:(\s[^)]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  final placeholderMatches = RegExp(r'\{(\w+)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  final manualPositions = <int>[];
  final openParRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanForManual = 0;

  while (true) {
    final m = openParRegex.firstMatch(rawPattern.substring(scanForManual));

    if (m == null) break;

    final pos = scanForManual + m.start;
    manualPositions.add(pos);
    scanForManual = pos + 1;
  }

  final manualCount = manualPositions.length;

  if (placeholderCount + manualCount != 4) {
    throw ArgumentError(
      'generic4 requires exactly four captures. '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  final placeholderDefs = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{(\w+)\}'), (match) {
      final name = match.group(1)!;
      final def = placeholders[name];

      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$name}". Supported: ${placeholders.keys.join(", ")}.',
        );
      }

      placeholderDefs.add(def);
      return def.regexPart;
    },
  );

  final manualDefs = <String>[];
  final manualGroupRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanIndex = 0;

  while (true) {
    final m = manualGroupRegex.firstMatch(regexBody.substring(scanIndex));

    if (m == null) break;

    final start = scanIndex + m.start;
    var depth = 1;
    var i = start + 1;

    while (i < regexBody.length && depth > 0) {
      if (regexBody[i] == '(') {
        depth++;
      }
      else if (regexBody[i] == ')') {
        depth--;
      }

      i++;
    }

    final inner = regexBody.substring(start + 1, i - 1);
    manualDefs.add(inner);
    scanIndex = i;
  }

  final ordered = <CaptureToken>[];
  var pIndex = 0, mIndex = 0;
  var idx = 0;

  while (idx < rawPattern.length) {
    final ph = RegExp(r'\{(\w+)\}').matchAsPrefix(rawPattern, idx);
    final op = RegExp(r'\(').matchAsPrefix(rawPattern, idx);

    if (ph != null) {
      ordered.add(CaptureToken.fromPlaceholder(placeholderDefs[pIndex++]));
      idx += ph.group(0)!.length;
    } else if (op != null) {
      if (rawPattern.substring(idx).startsWith('(?:')) {
        idx += 3;
      } else {
        ordered.add(CaptureToken.fromManual(manualDefs[mIndex++]));
        idx += 1;
      }
    } else {
      idx++;
    }
  }

  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?:').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;

  if (groupCount != 4 || ordered.length != 4) {
    throw ArgumentError(
      'generic4 expects exactly four capturing groups after replacement. '
          'Found $groupCount in regex:\n'
          '  $regexBody',
    );
  }

  final finalRegex = RegExp('^$regexBody\$');

  return StepDefinitionGeneric(finalRegex, 4, (args, context) async {
    final parsed = <dynamic>[];
    for (var i = 0; i < 4; i++) {
      final raw = args[i].toString();
      final token = ordered[i];

      if (token.kind == CaptureKind.placeholder) {
        parsed.add(token.placeholderDef!.parser(raw));
      } else {
        parsed.add(raw);
      }
    }

    final a = parsed[0] as T1;
    final b = parsed[1] as T2;
    final c = parsed[2] as T3;
    final d = parsed[3] as T4;

    await fn(a, b, c, d, context as W);
  });
}

/// Defines a step that expects exactly five captures (placeholders or manual).
/// Throws [ArgumentError] if the total count is not five.
StepDefinitionGeneric generic5<T1, T2, T3, T4, T5, W>(
  String rawPattern,
  Future<void> Function(T1, T2, T3, T4, T5, W world) fn,
) {
  // Rewrite any optional non-capturing group "(?: …)?"
  //    into "(…)?", so it becomes a single capturing group.
  rawPattern = rawPattern.replaceAllMapped(
    // Capture exactly the leading space plus everything until ")"
    RegExp(r'\(\?:(\s[^)]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  final placeholderMatches = RegExp(r'\{(\w+)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  final manualPositions = <int>[];
  final openParRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanForManual = 0;

  while (true) {
    final m = openParRegex.firstMatch(rawPattern.substring(scanForManual));

    if (m == null) break;

    final pos = scanForManual + m.start;
    manualPositions.add(pos);
    scanForManual = pos + 1;
  }

  final manualCount = manualPositions.length;

  if (placeholderCount + manualCount != 5) {
    throw ArgumentError(
      'generic5 requires exactly five captures. '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  final placeholderDefs = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{(\w+)\}'), (match) {
      final name = match.group(1)!;
      final def = placeholders[name];

      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$name}". Supported: ${placeholders.keys.join(", ")}.',
        );
      }

      placeholderDefs.add(def);
      return def.regexPart;
    },
  );

  final manualDefs = <String>[];
  final manualGroupRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanIndex = 0;

  while (true) {
    final m = manualGroupRegex.firstMatch(regexBody.substring(scanIndex));

    if (m == null) break;

    final start = scanIndex + m.start;
    var depth = 1;
    var i = start + 1;

    while (i < regexBody.length && depth > 0) {
      if (regexBody[i] == '(') {
        depth++;
      }
      else if (regexBody[i] == ')') {
        depth--;
      }

      i++;
    }

    final inner = regexBody.substring(start + 1, i - 1);
    manualDefs.add(inner);
    scanIndex = i;
  }

  final ordered = <CaptureToken>[];
  var pIndex = 0, mIndex = 0;
  var idx = 0;

  while (idx < rawPattern.length) {
    final ph = RegExp(r'\{(\w+)\}').matchAsPrefix(rawPattern, idx);
    final op = RegExp(r'\(').matchAsPrefix(rawPattern, idx);

    if (ph != null) {
      ordered.add(CaptureToken.fromPlaceholder(placeholderDefs[pIndex++]));
      idx += ph.group(0)!.length;
    } else if (op != null) {
      if (rawPattern.substring(idx).startsWith('(?:')) {
        idx += 3;
      } else {
        ordered.add(CaptureToken.fromManual(manualDefs[mIndex++]));
        idx += 1;
      }
    } else {
      idx++;
    }
  }

  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?:').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;

  if (groupCount != 5 || ordered.length != 5) {
    throw ArgumentError(
      'generic5 expects exactly five capturing groups after replacement. '
          'Found $groupCount in regex:\n'
          '  $regexBody',
    );
  }

  final finalRegex = RegExp('^$regexBody\$');

  return StepDefinitionGeneric(finalRegex, 5, (args, context) async {
    final parsed = <dynamic>[];

    for (var i = 0; i < 5; i++) {
      final raw = args[i].toString();
      final token = ordered[i];

      if (token.kind == CaptureKind.placeholder) {
        parsed.add(token.placeholderDef!.parser(raw));
      } else {
        parsed.add(raw);
      }
    }

    final a = parsed[0] as T1;
    final b = parsed[1] as T2;
    final c = parsed[2] as T3;
    final d = parsed[3] as T4;
    final e = parsed[4] as T5;

    await fn(a, b, c, d, e, context as W);
  });
}

/// Defines a step that expects exactly six captures (placeholders or manual).
/// Throws [ArgumentError] if the total count is not six.
StepDefinitionGeneric generic6<T1, T2, T3, T4, T5, T6, W>(
  String rawPattern,
  Future<void> Function(T1, T2, T3, T4, T5, T6, W world) fn,
) {
  // Rewrite any optional non-capturing group "(?: …)?"
  //    into "(…)?", so it becomes a single capturing group.
  rawPattern = rawPattern.replaceAllMapped(
    // Capture exactly the leading space plus everything until ")"
    RegExp(r'\(\?:(\s[^)]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  final placeholderMatches = RegExp(r'\{(\w+)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  final manualPositions = <int>[];
  final openParRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanForManual = 0;

  while (true) {
    final m = openParRegex.firstMatch(rawPattern.substring(scanForManual));

    if (m == null) break;

    final pos = scanForManual + m.start;
    manualPositions.add(pos);
    scanForManual = pos + 1;
  }

  final manualCount = manualPositions.length;

  if (placeholderCount + manualCount != 6) {
    throw ArgumentError(
      'generic6 requires exactly six captures. '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  final placeholderDefs = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{(\w+)\}'), (match) {
      final name = match.group(1)!;
      final def = placeholders[name];

      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$name}". Supported: ${placeholders.keys.join(", ")}.',
        );
      }

      placeholderDefs.add(def);
      return def.regexPart;
    },
  );

  final manualDefs = <String>[];
  final manualGroupRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanIndex = 0;

  while (true) {
    final m = manualGroupRegex.firstMatch(regexBody.substring(scanIndex));

    if (m == null) break;

    final start = scanIndex + m.start;
    var depth = 1;
    var i = start + 1;

    while (i < regexBody.length && depth > 0) {
      if (regexBody[i] == '(') {
        depth++;
      }
      else if (regexBody[i] == ')') {
        depth--;
      }

      i++;
    }

    final inner = regexBody.substring(start + 1, i - 1);
    manualDefs.add(inner);
    scanIndex = i;
  }

  final ordered = <CaptureToken>[];
  var pIndex = 0, mIndex = 0;
  var idx = 0;

  while (idx < rawPattern.length) {
    final ph = RegExp(r'\{(\w+)\}').matchAsPrefix(rawPattern, idx);
    final op = RegExp(r'\(').matchAsPrefix(rawPattern, idx);

    if (ph != null) {
      ordered.add(CaptureToken.fromPlaceholder(placeholderDefs[pIndex++]));
      idx += ph.group(0)!.length;
    } else if (op != null) {
      if (rawPattern.substring(idx).startsWith('(?:')) {
        idx += 3;
      } else {
        ordered.add(CaptureToken.fromManual(manualDefs[mIndex++]));
        idx += 1;
      }
    } else {
      idx++;
    }
  }

  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?:').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;

  if (groupCount != 6 || ordered.length != 6) {
    throw ArgumentError(
      'generic6 expects exactly six capturing groups after replacement. '
          'Found $groupCount in regex:\n'
          '  $regexBody',
    );
  }

  final finalRegex = RegExp('^$regexBody\$');

  return StepDefinitionGeneric(finalRegex, 6, (args, context) async {
    final parsed = <dynamic>[];

    for (var i = 0; i < 6; i++) {
      final raw = args[i].toString();
      final token = ordered[i];

      if (token.kind == CaptureKind.placeholder) {
        parsed.add(token.placeholderDef!.parser(raw));
      } else {
        parsed.add(raw);
      }
    }

    final a = parsed[0] as T1;
    final b = parsed[1] as T2;
    final c = parsed[2] as T3;
    final d = parsed[3] as T4;
    final e = parsed[4] as T5;
    final f = parsed[5] as T6;

    await fn(a, b, c, d, e, f, context as W);
  });
}