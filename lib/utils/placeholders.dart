import 'package:flutter_gherkin_parser/models/gherkin_table_model.dart';

/// Associates a regex fragment with a parser function for a placeholder token.
///
/// Each placeholder is identified by a name such as 'string' or 'table'. The
/// `regexPart` defines how to capture the relevant content inside quotes or
/// delimiters. The `parser` function transforms that captured raw value into
/// the target type (for example, converting JSON text into a `GherkinTable`).
class PlaceholderDef {
  /// Fragment of a regular expression that captures the placeholder’s content.
  ///
  /// For instance, r'"(.*?)"' captures any characters inside double quotes.
  /// For a table, r'"(<<<.+?>>>)"' captures an entire `<<<…>>>` block.
  final String regexPart;

  /// Function that converts the captured raw string (without outer quotes)
  /// into the desired type.
  ///
  /// If the placeholder is '{table}', this parser removes `<<<` and `>>>`
  /// and invokes `GherkinTable.fromJson`. If the placeholder is '{string}',
  /// this parser returns the raw text directly.
  final dynamic Function(String) parser;

  const PlaceholderDef({
    required this.regexPart,
    required this.parser,
  });
}

/// Defines which placeholder tokens are supported and how to handle them.
///
/// The key is the placeholder name (without braces), such as 'string' or 'table'.
/// Each entry specifies a regex fragment and a parser function. To support a new
/// token, add its name as a key with the appropriate `regexPart` and `parser`.
final Map<String, PlaceholderDef> placeholders = {
  'string': PlaceholderDef(
    /// Matches any sequence of characters (non‐greedy) between double quotes.
    regexPart: r'"(.*?)"',
    /// Returns the exact text captured between quotes.
    parser: (raw) => raw,
  ),
  'table': PlaceholderDef(
    /// Matches an entire <<<…>>> block (including delimiters) inside double quotes.
    ///
    /// The inner `.+?` is non‐greedy so that it stops at the first occurrence of `>>>`.
    regexPart: r'"(<<<.+?>>>)"',
    /// Strips the `<<<` and `>>>` delimiters, then parses the remaining JSON
    /// into a `GherkinTable` instance via `fromJson`.
    parser: (raw) {
      final jsonWithoutDelimiters = raw.replaceAll(RegExp(r'^<<<|>>>$'), '');
      return GherkinTable.fromJson(jsonWithoutDelimiters);
    },
  ),
};