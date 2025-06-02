import 'dart:core';

/// List of valid Gherkin step keywords.
/// If you need to add another keyword (e.g. “ButAlso”), update this list.
const List<String> _stepKeywords = [
  'Given',
  'When',
  'Then',
  'And',
  'But',
];

/// Dynamically builds the escaped keyword group for the RegExp.
/// Example result: r'^(?:Given|When|Then|And|But)'
final String _escapedKeywordGroup = _stepKeywords.map((kw) => RegExp.escape(kw)).join('|');

/// Pattern to detect if a line STARTS with one of the keywords 
/// (allowing optional leading whitespace). For example: “  Given user logs in”, “* something”, etc.
final RegExp stepLinePattern = RegExp(
  r'^\s*(?:' + _escapedKeywordGroup + r')\b',
  caseSensitive: false,
);

/// Pattern to “clean” (remove) the keyword and any following whitespace:
/// - Matches exactly “^(Given|When|Then|And|But)\s+”
/// - Removes the keyword plus the whitespace that follows it.
final RegExp cleanStepPattern = RegExp(
  r'^(?:' + _escapedKeywordGroup + r')\s+',
  caseSensitive: false,
);

/// Returns true if [line] begins with a valid step keyword 
/// (optionally preceded by whitespace).
bool isStepLine(String line) => stepLinePattern.hasMatch(line);

/// Removes the initial keyword (and the spaces that follow) from [stepText], 
/// returning only the “meaningful” part of the step.
/// Example: “Given user enters credentials” → “user enters credentials”
String cleanStepText(String stepText) {
  return stepText.replaceFirst(cleanStepPattern, '');
}