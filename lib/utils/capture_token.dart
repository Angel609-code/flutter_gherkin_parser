import 'package:flutter_gherkin_parser/utils/placeholders.dart';

/// Indicates whether a capture token represents a placeholder or a manual group.
enum CaptureKind { placeholder, manual }

/// Represents a single capture in the final regex, including how to parse it.
///
/// If [kind] == placeholder, then [placeholderDef] is non-null and holds the
/// regex fragment + parser for that placeholder. If [kind] == manual, then
/// [manualPattern] holds the inner regex for a manual `( … )` group.
class CaptureToken {
  /// Whether this token came from `{…}` or from `( … )`.
  final CaptureKind kind;

  /// If [kind] == placeholder, this is non-null and describes how to parse.
  final PlaceholderDef? placeholderDef;

  /// If [kind] == manual, this is non-null and holds the inner regex text.
  final String? manualPattern;

  /// Private constructor.
  CaptureToken._({
    required this.kind,
    this.placeholderDef,
    this.manualPattern,
  });

  /// Create a `CaptureToken` from a placeholder definition.
  factory CaptureToken.fromPlaceholder(PlaceholderDef def) {
    return CaptureToken._(
      kind: CaptureKind.placeholder,
      placeholderDef: def,
      manualPattern: null,
    );
  }

  /// Create a `CaptureToken` for a manual regex group `( … )`.
  factory CaptureToken.fromManual(String innerRegex) {
    return CaptureToken._(
      kind: CaptureKind.manual,
      placeholderDef: null,
      manualPattern: innerRegex,
    );
  }
}
