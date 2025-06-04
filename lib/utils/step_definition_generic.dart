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

/// Defines a step with no captures—just literal text (no regex at all).
///
/// For example:
///   generic('I click the button', (world) async { … });
/// will match exactly "I click the button" (case‐sensitive), and nothing else.
StepDefinitionGeneric generic<T, W>(
    String rawPattern,
    Future<void> Function(W world) fn,
    ) {
  // Escape the entire pattern so that every character is treated literally.
  final escaped = RegExp.escape(rawPattern);
  final finalRegex = RegExp('^$escaped\$');
  return StepDefinitionGeneric(finalRegex, 0, (args, context) async {
    await fn(context as W);
  });
}

/// Defines a step with exactly one capture (placeholder `{…}` or manual `( … )`):
///
/// ────  PLACEHOLDER TOKENS  ────
///
/// This method recognizes two built‐in placeholder tokens (keys in `placeholders`):
///
///  • `{string}`
///    • Internally backed by `regexPart = r'"(.*?)"'`
///    • Parser returns the exact text between the quotes (no further conversion).
///
///  • `{table}`
///    • Internally backed by `regexPart = r'"(<<<.+?>>>)"'`
///    • Parser strips `<<<` / `>>>` and feeds the remainder into `GherkinTable.fromJson(...)`.
///
/// At runtime, `{string}` and `{table}` count as exactly one capture each.
///
///
/// ────  MANUAL VS. NON-CAPTURING GROUPS  ────
///
///  • Manual capture `( … )`
///    – Any `(` not immediately preceded or followed by `?` is a “manual” capturing group.
///    – Example: `(foo|bar)`, `(\d+)`, `(urgent|normal)`.
///
///  • Non-capturing group `(?: … )`
///    – By default, `(?: … )` does NOT count as a capture.
///    – We rewrite **simple** `(?: <text> )?` → `( <text> )?` if `"<text>"` contains no `(` or `)`.
///      This makes an _optional literal fragment_ become a real capture (if there’s no nested parentheses).
///
///  • All other `(?…​)` forms (lookahead `(?=…)`, lookbehind `(?<=…)`, negative lookahead `(?!…)`, etc.)
///    are skipped entirely and never counted. We detect them by seeing `(` followed by `?`, then scanning past the matching `)`.
///    – They remain in the final regex but do not contribute to “capture count.”
///
/// *Note on “lookahead”:*
/// If you want to match and discard some literal text (e.g. ` into the search`), use a non‐capturing group, not a zero‐width lookahead. For example:
///
/// ```dart
/// // ✅ OK: consumes “ into the search”
/// r'I enter "(.*?)"(?: into the search)'
///
/// // ❌ Wrong: only asserts “ into the search” is next, but never consumes it
/// r'I enter "(.*?)"(?= into the search)'
/// ```
///
StepDefinitionGeneric generic1<T, W>(
  String rawPattern,
  Future<void> Function(T value, W world) fn,
) {
  // Rewrite only those "(?: …)?" whose interior has NO "(" or ")".
  rawPattern = rawPattern.replaceAllMapped(
    // A non-capturing group "(?: <space> [no‐paren chars] )?"
    RegExp(r'\(\?:(\s[^()]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  // Count placeholders "{Name}" (start with letter) in rawPattern.
  final placeholderMatches = RegExp(r'\{([A-Za-z]\w*)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  // Count manual "(…)" groups, ignoring ANY "(?…)".
  final manualPositions = <int>[];
  final openParRegex = RegExp(r'(?<!\?)\((?!\?)'); // "(" not preceded nor followed by "?"
  var scanForManual = 0;
  while (true) {
    final m = openParRegex.firstMatch(rawPattern.substring(scanForManual));
    if (m == null) break;
    final pos = scanForManual + m.start;
    manualPositions.add(pos);
    scanForManual = pos + 1;
  }
  final manualCount = manualPositions.length;

  // Must have exactly ONE capture total.
  if (placeholderCount + manualCount != 1) {
    throw ArgumentError(
      'generic1 requires exactly one capture (placeholder OR manual). '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  // Replace "{Token}" with its regex and collect PlaceholderDef.
  final placeholderDefs = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{([A-Za-z]\w*)\}'), (match) {
      final name = match.group(1)!;
      final def = placeholders[name];
      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$name}". '
              'Supported tokens: ${placeholders.keys.join(", ")}.',
        );
      }
      placeholderDefs.add(def);
      return def.regexPart;
    },
  );

  // Extract each manual "(…)" inner pattern from regexBody.
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
    // inner = everything between "(" and ")"
    final inner = regexBody.substring(start + 1, i - 1);
    manualDefs.add(inner);
    scanIndex = i;
  }

  // Build an ordered list of CaptureTokens (placeholder vs. manual).
  final ordered = <CaptureToken>[];
  var pIndex = 0, mIndex = 0;
  var idx = 0;
  while (idx < rawPattern.length) {
    // If "{Name}", record a placeholder.
    final ph = RegExp(r'\{([A-Za-z]\w*)\}').matchAsPrefix(rawPattern, idx);
    if (ph != null) {
      ordered.add(CaptureToken.fromPlaceholder(placeholderDefs[pIndex++]));
      idx += ph.group(0)!.length;
      continue;
    }

    // If we see "(":
    if (rawPattern[idx] == '(') {
      // If it’s exactly "(?:", skip only those 3 chars so that
      // nested "(…)" inside remain visible later.
      if (idx + 2 < rawPattern.length && rawPattern.substring(idx, idx + 3) == '(?:') {
        idx += 3;
        continue;
      }
      // If it’s any other "(?…)", skip the entire "(?…)" block:
      if (idx + 1 < rawPattern.length && rawPattern[idx + 1] == '?') {
        var depth = 1;
        var i = idx + 2; // just after "(?"
        while (i < rawPattern.length && depth > 0) {
          if (rawPattern[i] == '(') {
            depth++;
          } else if (rawPattern[i] == ')') {
            depth--;
          }
          i++;
        }
        idx = i; // one past the closing ")"
        continue;
      }
      // Otherwise, it’s a plain "(…)" → manual capture:
      ordered.add(CaptureToken.fromManual(manualDefs[mIndex++]));
      idx += 1; // step past "("
      continue;
    }

    // Otherwise, advance one char
    idx++;
  }

  // Verify that, in regexBody, there is exactly ONE “real” capturing group.
  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  // Subtract ALL "(?" variants so lookahead/lookbehind/non-capturing are ignored:
  final nonCaptureParens = RegExp(r'\(\?').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;
  if (groupCount != 1 || ordered.length != 1) {
    throw ArgumentError(
      'generic1 expects exactly one capturing group after replacement. '
          'Found $groupCount in regex:\n'
          '  $regexBody',
    );
  }

  // Build the anchored regex and return StepDefinitionGeneric:
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

/// Defines a step with exactly two captures (placeholder `{…}` or manual `( … )`):
///
/// ────  PLACEHOLDER TOKENS  ────
///
/// This method recognizes two built‐in placeholder tokens (keys in `placeholders`):
///
///  • `{string}`
///    • Internally backed by `regexPart = r'"(.*?)"'`
///    • Parser returns the exact text between the quotes (no further conversion).
///
///  • `{table}`
///    • Internally backed by `regexPart = r'"(<<<.+?>>>)"'`
///    • Parser strips `<<<` / `>>>` and feeds the remainder into `GherkinTable.fromJson(...)`.
///
/// At runtime, `{string}` and `{table}` count as exactly one capture each.
///
///
/// ────  MANUAL VS. NON-CAPTURING GROUPS  ────
///
///  • Manual capture `( … )`
///    – Any `(` not immediately preceded or followed by `?` is a “manual” capturing group.
///    – Example: `(foo|bar)`, `(\d+)`, `(urgent|normal)`.
///
///  • Non-capturing group `(?: … )`
///    – By default, `(?: … )` does NOT count as a capture.
///    – We rewrite **simple** `(?: <text> )?` → `( <text> )?` if `"<text>"` contains no `(` or `)`.
///      This makes an _optional literal fragment_ become a real capture (if there’s no nested parentheses).
///
///  • All other `(?…​)` forms (lookahead `(?=…)`, lookbehind `(?<=…)`, negative lookahead `(?!…)`, etc.)
///    are skipped entirely and never counted. We detect them by seeing `(` followed by `?`, then scanning past the matching `)`.
///    – They remain in the final regex but do not contribute to “capture count.”
///
/// *Note on “lookahead”:*
/// If you want to match and discard some literal text (e.g. ` into the search`), use a non‐capturing group, not a zero‐width lookahead. For example:
///
/// ```dart
/// // ✅ OK: consumes “ into the search”
/// r'I enter "(.*?)"(?: into the search)'
///
/// // ❌ Wrong: only asserts “ into the search” is next, but never consumes it
/// r'I enter "(.*?)"(?= into the search)'
/// ```
///
StepDefinitionGeneric generic2<T1, T2, W>(
  String rawPattern,
  Future<void> Function(T1, T2, W world) fn,
) {
  // Rewrite only those "(?: …)?" whose interior has NO "(" or ")".
  rawPattern = rawPattern.replaceAllMapped(
    RegExp(r'\(\?:(\s[^()]+?)\)\?'),
        (m) => '(${m.group(1)})?',
  );

  // Count placeholders "{Name}" (letter‐started) in rawPattern.
  final placeholderMatches = RegExp(r'\{([A-Za-z]\w*)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  // Count manual "(…)" groups, ignoring ANY "(?…)".
  final manualMatches = <int>[];
  final openParRegex = RegExp(r'(?<!\?)\((?!\?)');
  var scanForManual = 0;
  while (true) {
    final m = openParRegex.firstMatch(rawPattern.substring(scanForManual));
    if (m == null) break;
    final start = scanForManual + m.start;
    manualMatches.add(start);
    scanForManual = start + 1;
  }
  final manualCount = manualMatches.length;

  // Must have exactly TWO total captures.
  if (placeholderCount + manualCount != 2) {
    throw ArgumentError(
      'generic2 requires exactly two captures '
          '(sum of placeholders and manual groups). '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  // Replace "{token}" with its regexPart; collect PlaceholderDefs.
  final placeholderTokens = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{([A-Za-z]\w*)\}'), (match) {
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

  // Extract each manual "(…)" inner pattern from regexBody (ignore all "(?…)" forms).
  final manualTokens = <String>[];
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
    manualTokens.add(inner);
    scanIndex = i;
  }

  // Build orderedCaptures by scanning rawPattern left→right.
  final orderedCaptures = <CaptureToken>[];
  var placeholderIndex = 0;
  var manualIndex = 0;
  var idx = 0;
  while (idx < rawPattern.length) {
    final phMatch = RegExp(r'\{([A-Za-z]\w*)\}').matchAsPrefix(rawPattern, idx);
    if (phMatch != null) {
      orderedCaptures.add(
        CaptureToken.fromPlaceholder(placeholderTokens[placeholderIndex++]),
      );
      idx += phMatch.group(0)!.length;
      continue;
    }
    if (rawPattern[idx] == '(') {
      // If "(?:", skip just "(?:".
      if (idx + 2 < rawPattern.length && rawPattern.substring(idx, idx + 3) == '(?:') {
        idx += 3;
        continue;
      }
      // Else if "(?…)", skip entire lookaround.
      if (idx + 1 < rawPattern.length && rawPattern[idx + 1] == '?') {
        var depth = 1;
        var i = idx + 2;
        while (i < rawPattern.length && depth > 0) {
          if (rawPattern[i] == '(') {
            depth++;
          }
          else if (rawPattern[i] == ')') {
            depth--;
          }
          i++;
        }
        idx = i;
        continue;
      }
      // Otherwise, plain "(…)" → manual capture.
      orderedCaptures.add(
        CaptureToken.fromManual(manualTokens[manualIndex++]),
      );
      idx += 1;
      continue;
    }
    idx++;
  }

  // Verify final regexBody has exactly TWO capturing groups.
  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;
  if (groupCount != 2 || orderedCaptures.length != 2) {
    throw ArgumentError(
      'generic2 expects exactly two capturing groups after replacement. '
          'Found $groupCount groups in generated regex:\n'
          '  $regexBody',
    );
  }

  // Build anchored regex and return StepDefinitionGeneric that expects 2 args.
  final finalRegex = RegExp('^$regexBody\$');
  return StepDefinitionGeneric(finalRegex, 2, (args, context) async {
    final parsed = <dynamic>[];
    for (var i = 0; i < 2; i++) {
      final rawText = args[i].toString();
      final token = orderedCaptures[i];
      if (token.kind == CaptureKind.placeholder) {
        parsed.add(token.placeholderDef!.parser(rawText));
      } else {
        parsed.add(rawText);
      }
    }
    final a = parsed[0] as T1;
    final b = parsed[1] as T2;

    await fn(a, b, context as W);
  });
}

/// Defines a step with exactly three captures (placeholder `{…}` or manual `( … )`):
///
/// ────  PLACEHOLDER TOKENS  ────
///
/// This method recognizes two built‐in placeholder tokens (keys in `placeholders`):
///
///  • `{string}`
///    • Internally backed by `regexPart = r'"(.*?)"'`
///    • Parser returns the exact text between the quotes (no further conversion).
///
///  • `{table}`
///    • Internally backed by `regexPart = r'"(<<<.+?>>>)"'`
///    • Parser strips `<<<` / `>>>` and feeds the remainder into `GherkinTable.fromJson(...)`.
///
/// At runtime, `{string}` and `{table}` count as exactly one capture each.
///
///
/// ────  MANUAL VS. NON-CAPTURING GROUPS  ────
///
///  • Manual capture `( … )`
///    – Any `(` not immediately preceded or followed by `?` is a “manual” capturing group.
///    – Example: `(foo|bar)`, `(\d+)`, `(urgent|normal)`.
///
///  • Non-capturing group `(?: … )`
///    – By default, `(?: … )` does NOT count as a capture.
///    – We rewrite **simple** `(?: <text> )?` → `( <text> )?` if `"<text>"` contains no `(` or `)`.
///      This makes an _optional literal fragment_ become a real capture (if there’s no nested parentheses).
///
///  • All other `(?…​)` forms (lookahead `(?=…)`, lookbehind `(?<=…)`, negative lookahead `(?!…)`, etc.)
///    are skipped entirely and never counted. We detect them by seeing `(` followed by `?`, then scanning past the matching `)`.
///    – They remain in the final regex but do not contribute to “capture count.”
///
/// *Note on “lookahead”:*
/// If you want to match and discard some literal text (e.g. ` into the search`), use a non‐capturing group, not a zero‐width lookahead. For example:
///
/// ```dart
/// // ✅ OK: consumes “ into the search”
/// r'I enter "(.*?)"(?: into the search)'
///
/// // ❌ Wrong: only asserts “ into the search” is next, but never consumes it
/// r'I enter "(.*?)"(?= into the search)'
/// ```
///
StepDefinitionGeneric generic3<T1, T2, T3, W>(
  String rawPattern,
  Future<void> Function(T1, T2, T3, W world) fn,
) {
  // Rewrite ONLY those "(?: …)?" whose interior contains NO "(" or ")".
  rawPattern = rawPattern.replaceAllMapped(
    RegExp(r'\(\?:(\s[^()]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  // Count "{Name}" placeholders.
  final placeholderMatches = RegExp(r'\{([A-Za-z]\w*)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  // Count manual "(…)" groups, ignoring ANY "(?…)".
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

  // Must have exactly THREE total captures.
  if (placeholderCount + manualCount != 3) {
    throw ArgumentError(
      'generic3 requires exactly three captures '
          '(sum of placeholders and manual groups). '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  // Replace "{token}" with its regexPart; collect PlaceholderDefs.
  final placeholderDefs = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{([A-Za-z]\w*)\}'), (match) {
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

  // Extract inner text of each manual "(…)" from regexBody (ignore "(?…)" forms).
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

  // Build an ordered list of CaptureTokens by scanning rawPattern left→right.
  final ordered = <CaptureToken>[];
  var pIndex = 0, mIndex = 0;
  var idx = 0;
  while (idx < rawPattern.length) {
    // If "{Name}", placeholder
    final ph = RegExp(r'\{([A-Za-z]\w*)\}').matchAsPrefix(rawPattern, idx);
    if (ph != null) {
      ordered.add(CaptureToken.fromPlaceholder(placeholderDefs[pIndex++]));
      idx += ph.group(0)!.length;
      continue;
    }
    // If "(" ...
    if (rawPattern[idx] == '(') {
      // If "(?:", skip just "(?:"
      if (idx + 2 < rawPattern.length && rawPattern.substring(idx, idx + 3) == '(?:') {
        idx += 3;
        continue;
      }
      // If any other "(?…)", skip full "(?…)" block
      if (idx + 1 < rawPattern.length && rawPattern[idx + 1] == '?') {
        var depth = 1;
        var i = idx + 2;
        while (i < rawPattern.length && depth > 0) {
          if (rawPattern[i] == '(') {
            depth++;
          } else if (rawPattern[i] == ')') {
            depth--;
          }
          i++;
        }
        idx = i;
        continue;
      }
      // Otherwise: manual capture
      ordered.add(CaptureToken.fromManual(manualDefs[mIndex++]));
      idx += 1;
      continue;
    }
    idx++;
  }

  // Verify final regexBody has exactly THREE capturing groups.
  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;
  if (groupCount != 3 || ordered.length != 3) {
    throw ArgumentError(
      'generic3 expects exactly three capturing groups after replacement. '
          'Found $groupCount in regex:\n'
          '  $regexBody',
    );
  }

  // Build anchored regex and return StepDefinitionGeneric (3 args).
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

/// Defines a step with exactly four captures (placeholder `{…}` or manual `( … )`):
///
/// ────  PLACEHOLDER TOKENS  ────
///
/// This method recognizes two built‐in placeholder tokens (keys in `placeholders`):
///
///  • `{string}`
///    • Internally backed by `regexPart = r'"(.*?)"'`
///    • Parser returns the exact text between the quotes (no further conversion).
///
///  • `{table}`
///    • Internally backed by `regexPart = r'"(<<<.+?>>>)"'`
///    • Parser strips `<<<` / `>>>` and feeds the remainder into `GherkinTable.fromJson(...)`.
///
/// At runtime, `{string}` and `{table}` count as exactly one capture each.
///
///
/// ────  MANUAL VS. NON-CAPTURING GROUPS  ────
///
///  • Manual capture `( … )`
///    – Any `(` not immediately preceded or followed by `?` is a “manual” capturing group.
///    – Example: `(foo|bar)`, `(\d+)`, `(urgent|normal)`.
///
///  • Non-capturing group `(?: … )`
///    – By default, `(?: … )` does NOT count as a capture.
///    – We rewrite **simple** `(?: <text> )?` → `( <text> )?` if `"<text>"` contains no `(` or `)`.
///      This makes an _optional literal fragment_ become a real capture (if there’s no nested parentheses).
///
///  • All other `(?…​)` forms (lookahead `(?=…)`, lookbehind `(?<=…)`, negative lookahead `(?!…)`, etc.)
///    are skipped entirely and never counted. We detect them by seeing `(` followed by `?`, then scanning past the matching `)`.
///    – They remain in the final regex but do not contribute to “capture count.”
///
/// *Note on “lookahead”:*
/// If you want to match and discard some literal text (e.g. ` into the search`), use a non‐capturing group, not a zero‐width lookahead. For example:
///
/// ```dart
/// // ✅ OK: consumes “ into the search”
/// r'I enter "(.*?)"(?: into the search)'
///
/// // ❌ Wrong: only asserts “ into the search” is next, but never consumes it
/// r'I enter "(.*?)"(?= into the search)'
/// ```
///
StepDefinitionGeneric generic4<T1, T2, T3, T4, W>(
  String rawPattern,
  Future<void> Function(T1, T2, T3, T4, W world) fn,
) {
  // Rewrite only those "(?: …)?" whose interior contains NO "(" or ")".
  rawPattern = rawPattern.replaceAllMapped(
    RegExp(r'\(\?:(\s[^()]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  // Count "{Name}" placeholders (letter‐started).
  final placeholderMatches = RegExp(r'\{([A-Za-z]\w*)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  // Count manual "(…)" groups, ignoring ANY "(?…)".
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

  // Must have exactly FOUR total captures.
  if (placeholderCount + manualCount != 4) {
    throw ArgumentError(
      'generic4 requires exactly four captures. '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  // Replace "{token}" with its regex; collect PlaceholderDefs.
  final placeholderDefs = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{([A-Za-z]\w*)\}'), (match) {
      final name = match.group(1)!;
      final def = placeholders[name];
      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$name}". Supported tokens: ${placeholders.keys.join(", ")}.',
        );
      }
      placeholderDefs.add(def);
      return def.regexPart;
    },
  );

  // Extract each manual "(…)" inner pattern from regexBody (ignore "(?…)" forms).
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

  // Build an ordered list of CaptureTokens by scanning rawPattern.
  final ordered = <CaptureToken>[];
  var pIndex = 0, mIndex = 0;
  var idx = 0;
  while (idx < rawPattern.length) {
    // If "{Name}", placeholder
    final phMatch = RegExp(r'\{([A-Za-z]\w*)\}').matchAsPrefix(rawPattern, idx);
    if (phMatch != null) {
      ordered.add(CaptureToken.fromPlaceholder(placeholderDefs[pIndex++]));
      idx += phMatch.group(0)!.length;
      continue;
    }
    // If "(" ...
    if (rawPattern[idx] == '(') {
      // If "(?:", skip "(?:"
      if (idx + 2 < rawPattern.length && rawPattern.substring(idx, idx + 3) == '(?:') {
        idx += 3;
        continue;
      }
      // Else if any "(?…)", skip full lookaround
      if (idx + 1 < rawPattern.length && rawPattern[idx + 1] == '?') {
        var depth = 1;
        var i = idx + 2;
        while (i < rawPattern.length && depth > 0) {
          if (rawPattern[i] == '(') {
            depth++;
          } else if (rawPattern[i] == ')') {
            depth--;
          }
          i++;
        }
        idx = i;
        continue;
      }
      // Else, plain "(…)" → manual capture
      ordered.add(CaptureToken.fromManual(manualDefs[mIndex++]));
      idx += 1;
      continue;
    }
    idx++;
  }

  // Verify final regexBody has exactly FOUR capturing groups.
  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;
  if (groupCount != 4 || ordered.length != 4) {
    throw ArgumentError(
      'generic4 expects exactly four capturing groups after replacement. '
          'Found $groupCount in regex:\n'
          '  $regexBody',
    );
  }

  // Build anchored regex and return StepDefinitionGeneric (4 args).
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

/// Defines a step with exactly five captures (placeholder `{…}` or manual `( … )`):
///
/// ────  PLACEHOLDER TOKENS  ────
///
/// This method recognizes two built‐in placeholder tokens (keys in `placeholders`):
///
///  • `{string}`
///    • Internally backed by `regexPart = r'"(.*?)"'`
///    • Parser returns the exact text between the quotes (no further conversion).
///
///  • `{table}`
///    • Internally backed by `regexPart = r'"(<<<.+?>>>)"'`
///    • Parser strips `<<<` / `>>>` and feeds the remainder into `GherkinTable.fromJson(...)`.
///
/// At runtime, `{string}` and `{table}` count as exactly one capture each.
///
///
/// ────  MANUAL VS. NON-CAPTURING GROUPS  ────
///
///  • Manual capture `( … )`
///    – Any `(` not immediately preceded or followed by `?` is a “manual” capturing group.
///    – Example: `(foo|bar)`, `(\d+)`, `(urgent|normal)`.
///
///  • Non-capturing group `(?: … )`
///    – By default, `(?: … )` does NOT count as a capture.
///    – We rewrite **simple** `(?: <text> )?` → `( <text> )?` if `"<text>"` contains no `(` or `)`.
///      This makes an _optional literal fragment_ become a real capture (if there’s no nested parentheses).
///
///  • All other `(?…​)` forms (lookahead `(?=…)`, lookbehind `(?<=…)`, negative lookahead `(?!…)`, etc.)
///    are skipped entirely and never counted. We detect them by seeing `(` followed by `?`, then scanning past the matching `)`.
///    – They remain in the final regex but do not contribute to “capture count.”
///
/// *Note on “lookahead”:*
/// If you want to match and discard some literal text (e.g. ` into the search`), use a non‐capturing group, not a zero‐width lookahead. For example:
///
/// ```dart
/// // ✅ OK: consumes “ into the search”
/// r'I enter "(.*?)"(?: into the search)'
///
/// // ❌ Wrong: only asserts “ into the search” is next, but never consumes it
/// r'I enter "(.*?)"(?= into the search)'
/// ```
///
StepDefinitionGeneric generic5<T1, T2, T3, T4, T5, W>(
  String rawPattern,
  Future<void> Function(T1, T2, T3, T4, T5, W world) fn,
) {
  // Rewrite only those "(?: …)?" whose interior contains NO "(" or ")".
  rawPattern = rawPattern.replaceAllMapped(
    RegExp(r'\(\?:(\s[^()]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  // Count "{Name}" placeholders (letter‐started).
  final placeholderMatches = RegExp(r'\{([A-Za-z]\w*)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  // Count manual "(…)" groups, ignoring ANY "(?…)".
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

  // Must have exactly FIVE total captures.
  if (placeholderCount + manualCount != 5) {
    throw ArgumentError(
      'generic5 requires exactly five captures. '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  // Replace "{token}" with its regex; collect PlaceholderDefs.
  final placeholderDefs = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{([A-Za-z]\w*)\}'), (match) {
      final name = match.group(1)!;
      final def = placeholders[name];
      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$name}". Supported tokens: ${placeholders.keys.join(", ")}.',
        );
      }
      placeholderDefs.add(def);
      return def.regexPart;
    },
  );

  // Extract each manual "(…)" inner pattern from regexBody (ignore "(?…)" forms).
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

  // Build ordered list of CaptureTokens by scanning rawPattern.
  final ordered = <CaptureToken>[];
  var pIndex = 0, mIndex = 0;
  var idx = 0;
  while (idx < rawPattern.length) {
    // If "{Name}", placeholder
    final phMatch = RegExp(r'\{([A-Za-z]\w*)\}').matchAsPrefix(rawPattern, idx);
    if (phMatch != null) {
      ordered.add(CaptureToken.fromPlaceholder(placeholderDefs[pIndex++]));
      idx += phMatch.group(0)!.length;
      continue;
    }
    // If "(" …
    if (rawPattern[idx] == '(') {
      // If "(?:", skip just those three chars.
      if (idx + 2 < rawPattern.length && rawPattern.substring(idx, idx + 3) == '(?:') {
        idx += 3;
        continue;
      }
      // Else if "(?…)", skip entire "(?…)" block.
      if (idx + 1 < rawPattern.length && rawPattern[idx + 1] == '?') {
        var depth = 1;
        var i = idx + 2;
        while (i < rawPattern.length && depth > 0) {
          if (rawPattern[i] == '(') {
            depth++;
          } else if (rawPattern[i] == ')') {
            depth--;
          }
          i++;
        }
        idx = i;
        continue;
      }
      // Otherwise, plain "(…)" → manual capture.
      ordered.add(CaptureToken.fromManual(manualDefs[mIndex++]));
      idx += 1;
      continue;
    }
    idx++;
  }

  // Verify final regexBody has exactly FIVE capturing groups.
  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;
  if (groupCount != 5 || ordered.length != 5) {
    throw ArgumentError(
      'generic5 expects exactly five capturing groups after replacement. '
          'Found $groupCount in regex:\n'
          '  $regexBody',
    );
  }

  // Build the anchored regex and return StepDefinitionGeneric (5 args).
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

/// Defines a step with exactly six captures (placeholder `{…}` or manual `( … )`):
///
/// ────  PLACEHOLDER TOKENS  ────
///
/// This method recognizes two built‐in placeholder tokens (keys in `placeholders`):
///
///  • `{string}`
///    • Internally backed by `regexPart = r'"(.*?)"'`
///    • Parser returns the exact text between the quotes (no further conversion).
///
///  • `{table}`
///    • Internally backed by `regexPart = r'"(<<<.+?>>>)"'`
///    • Parser strips `<<<` / `>>>` and feeds the remainder into `GherkinTable.fromJson(...)`.
///
/// At runtime, `{string}` and `{table}` count as exactly one capture each.
///
///
/// ────  MANUAL VS. NON-CAPTURING GROUPS  ────
///
///  • Manual capture `( … )`
///    – Any `(` not immediately preceded or followed by `?` is a “manual” capturing group.
///    – Example: `(foo|bar)`, `(\d+)`, `(urgent|normal)`.
///
///  • Non-capturing group `(?: … )`
///    – By default, `(?: … )` does NOT count as a capture.
///    – We rewrite **simple** `(?: <text> )?` → `( <text> )?` if `"<text>"` contains no `(` or `)`.
///      This makes an _optional literal fragment_ become a real capture (if there’s no nested parentheses).
///
///  • All other `(?…​)` forms (lookahead `(?=…)`, lookbehind `(?<=…)`, negative lookahead `(?!…)`, etc.)
///    are skipped entirely and never counted. We detect them by seeing `(` followed by `?`, then scanning past the matching `)`.
///    – They remain in the final regex but do not contribute to “capture count.”
///
/// *Note on “lookahead”:*
/// If you want to match and discard some literal text (e.g. ` into the search`), use a non‐capturing group, not a zero‐width lookahead. For example:
///
/// ```dart
/// // ✅ OK: consumes “ into the search”
/// r'I enter "(.*?)"(?: into the search)'
///
/// // ❌ Wrong: only asserts “ into the search” is next, but never consumes it
/// r'I enter "(.*?)"(?= into the search)'
/// ```
///
StepDefinitionGeneric generic6<T1, T2, T3, T4, T5, T6, W>(
  String rawPattern,
  Future<void> Function(T1, T2, T3, T4, T5, T6, W world) fn,
) {
  // Rewrite only those "(?: …)?" whose interior contains NO "(" or ")".
  rawPattern = rawPattern.replaceAllMapped(
    RegExp(r'\(\?:(\s[^()]+?)\)\?'), (m) => '(${m.group(1)})?',
  );

  // Count "{Name}" placeholders (letter‐started).
  final placeholderMatches = RegExp(r'\{([A-Za-z]\w*)\}').allMatches(rawPattern);
  final placeholderCount = placeholderMatches.length;

  // Count manual "(…)" groups, ignoring ANY "(?…)".
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

  // Must have exactly SIX total captures.
  if (placeholderCount + manualCount != 6) {
    throw ArgumentError(
      'generic6 requires exactly six captures. '
          'Found $placeholderCount placeholder(s) and $manualCount manual group(s) in:\n'
          '  $rawPattern',
    );
  }

  // Replace "{token}" with its regexPart; collect PlaceholderDefs.
  final placeholderDefs = <PlaceholderDef>[];
  var regexBody = rawPattern.replaceAllMapped(
    RegExp(r'\{([A-Za-z]\w*)\}'), (match) {
      final name = match.group(1)!;
      final def = placeholders[name];
      if (def == null) {
        throw ArgumentError(
          'Unsupported placeholder "{$name}". Supported tokens: ${placeholders.keys.join(", ")}.',
        );
      }
      placeholderDefs.add(def);
      return def.regexPart;
    },
  );

  // Extract each manual "(…)" inner pattern from regexBody (ignore "(?…)" forms).
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

  // Build an ordered list of CaptureTokens by scanning rawPattern.
  final ordered = <CaptureToken>[];
  var pIndex = 0, mIndex = 0;
  var idx = 0;
  while (idx < rawPattern.length) {
    // If "{Name}", placeholder
    final phMatch = RegExp(r'\{([A-Za-z]\w*)\}').matchAsPrefix(rawPattern, idx);
    if (phMatch != null) {
      ordered.add(CaptureToken.fromPlaceholder(placeholderDefs[pIndex++]));
      idx += phMatch.group(0)!.length;
      continue;
    }
    // If "(" …
    if (rawPattern[idx] == '(') {
      // If "(?:", skip those three chars
      if (idx + 2 < rawPattern.length && rawPattern.substring(idx, idx + 3) == '(?:') {
        idx += 3;
        continue;
      }
      // Else if any "(?…)", skip full lookaround
      if (idx + 1 < rawPattern.length && rawPattern[idx + 1] == '?') {
        var depth = 1;
        var i = idx + 2;
        while (i < rawPattern.length && depth > 0) {
          if (rawPattern[i] == '(') {
            depth++;
          }
          else if (rawPattern[i] == ')') {
            depth--;
          }
          i++;
        }
        idx = i;
        continue;
      }
      // Otherwise, plain "(…)" → manual capture
      ordered.add(CaptureToken.fromManual(manualDefs[mIndex++]));
      idx += 1;
      continue;
    }
    // Otherwise, skip one char
    idx++;
  }

  // Verify final regexBody has exactly SIX capturing groups.
  final totalLeftParens = RegExp(r'\(').allMatches(regexBody).length;
  final nonCaptureParens = RegExp(r'\(\?').allMatches(regexBody).length;
  final groupCount = totalLeftParens - nonCaptureParens;
  if (groupCount != 6 || ordered.length != 6) {
    throw ArgumentError(
      'generic6 expects exactly six capturing groups after replacement. '
          'Found $groupCount in regex:\n'
          '  $regexBody',
    );
  }

  // Build anchored regex and return StepDefinitionGeneric (6 args).
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
