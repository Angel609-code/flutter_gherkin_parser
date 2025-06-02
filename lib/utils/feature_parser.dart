import 'dart:convert';

import 'package:flutter_gherkin_parser/utils/steps_keywords.dart';

class FeatureParser {
  Feature parse(String content) {
    final rawLines = content.split('\n');
    Feature? feature;
    Scenario? currentScenario;
    bool inBackground = false;

    // Regex to detect a “pure table row” (a line that starts and ends with '|')
    final tableRowRegex = RegExp(r'^\s*\|.*\|\s*$');

    for (int i = 0; i< rawLines.length; i++) {
      final String rawLine = rawLines[i];
      final String line = rawLine.trim();

      if (line.startsWith('Feature:')) {
        feature = Feature(name: line.substring('Feature:'.length).trim());
        inBackground = false;
        continue;
      }

      if (line.startsWith('Background:')) {
        // Start collecting background steps
        inBackground = true;
        feature?.background = Background();
        continue;
      }

      if (line.startsWith('Scenario:')) {
        // Stop background collection once a scenario begins
        inBackground = false;
        currentScenario = Scenario(name: line.substring('Scenario:'.length).trim());
        feature?.scenarios.add(currentScenario);
        continue;
      }

      // Skip pure “table row” lines—they will be consumed below, not treated as separate steps
      if (tableRowRegex.hasMatch(rawLine)) {
        continue;
      }

      // If it matches a stepLinePattern, create a Step
      if (stepLinePattern.hasMatch(line)) {
        // By default, stepText is just “line”
        String stepText = line;

        // Check if the next line(s) form a Gherkin table
        if (i + 1 < rawLines.length && tableRowRegex.hasMatch(rawLines[i + 1])) {
          final rows = <TableRow>[];

          // Consume all consecutive tableRowRegex lines
          while (i + 1 < rawLines.length && tableRowRegex.hasMatch(rawLines[i + 1])) {
            i++;
            final tableLine = rawLines[i].trim();
            // Strip leading/trailing '|' and split into cells
            final cells = tableLine
                .substring(1, tableLine.length - 1)
                .split('|')
                .map((c) => c.trim().isEmpty ? null : c.trim())
                .toList();

            rows.add(TableRow(cells));
          }

          // Determine header vs data rows
          TableRow? header;
          Iterable<TableRow> dataRows;

          if (rows.length > 1) {
            header = rows.first;
            dataRows = rows.sublist(1);
          } else {
            header = null;
            dataRows = rows;
          }

          final table = GherkinTable(dataRows.toList(), header);

          // Serialize to JSON and append to stepText with a unique delimiter
          final tableJson = table.toJson();
          // Use “<<<JSON>>>” as a marker. We guarantee that no normal step text will contain “<<<” or “>>>”.
          stepText = '$stepText "<<<$tableJson>>>"';
        }

        // Now create the Step with the combined text
        final step = Step(text: stepText);
        if (inBackground) {
          feature?.background?.steps.add(step);
        } else {
          currentScenario?.steps.add(step);
        }
      }
    }

    if (feature == null) {
      throw Exception('No feature found in file.');
    }

    return feature;
  }
}

class Feature {
  final String name;
  Background? background;
  final List<Scenario> scenarios = [];

  Feature({required this.name});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (background != null) 'background': background!.toJson(),
      'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

class Background {
  final List<Step> steps = [];

  Map<String, dynamic> toJson() {
    return {
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

class Scenario {
  final String name;
  final List<Step> steps = [];

  Scenario({required this.name});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

class Step {
  final String text;
  Step({required this.text});

  Map<String, dynamic> toJson() {
    return {
      'text': text,
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

/// Represents one row in a Gherkin table.
class TableRow {
  /// The raw cell values (null if a cell was empty).
  final List<String?> columns;

  TableRow(this.columns);

  /// Create a deep copy of this row.
  TableRow clone() => TableRow(List<String?>.from(columns));

  /// Helper: convert this row to a list of cell strings (nullable).
  List<String?> toList() => List<String?>.from(columns);

  /// Factory: create a TableRow from a JSON list of strings/nulls.
  factory TableRow.fromJson(List<dynamic> jsonColumns) {
    return TableRow(jsonColumns.map((e) => e as String?).toList());
  }

  /// Serialize this row to a JSON-compatible list.
  List<String?> toJson() => toList();
}

/// A parsed Gherkin table, possibly with a header row.
///
/// Internally, if a header is present, [header] holds the first row’s column names,
/// and [rows] holds the subsequent data rows. If there is no header, [header] is null
/// and [rows] holds every row as data.
class GherkinTable {
  final TableRow? header;
  final List<TableRow> rows;

  /// Construct a table from (optional) header + data rows.
  GherkinTable(this.rows, this.header);

  /// Produce an iterable of maps, one map per data row.
  ///
  /// If [header] is not null, keys come from header.columns;
  /// otherwise, keys are stringify indices ("0", "1", …).
  Iterable<Map<String, String?>> asMap() sync* {
    if (header != null) {
      // Use header columns as keys
      final keys = header!.columns.map((c) => c ?? '').toList();
      for (final row in rows) {
        final map = <String, String?>{};
        for (var i = 0; i < keys.length; i++) {
          final key = keys[i];
          final value = (i < row.columns.length) ? row.columns[i] : null;
          map[key] = value;
        }
        yield map;
      }
    } else {
      // No header: use column index as string key
      for (final row in rows) {
        final map = <String, String?>{};
        for (var i = 0; i < row.columns.length; i++) {
          map[i.toString()] = row.columns[i];
        }
        yield map;
      }
    }
  }

  /// Serialize to a JSON string of the form:
  ///   { "header": [ … ], "rows": [ [ … ], [ … ], … ] }
  String toJson() {
    final headerJson = header?.toJson(); // List<String?> or null
    final rowsJson = rows.map((r) => r.toJson()).toList();
    final payload = <String, dynamic>{};

    if (headerJson != null) {
      payload['header'] = headerJson;
    }

    payload['rows'] = rowsJson;
    return jsonEncode(payload);
  }

  /// Reconstruct a GherkinTable from its JSON string.
  ///
  /// Expected format:
  ///   { "header": [ … ], "rows": [ [ … ], [ … ], … ] }
  static GherkinTable fromJson(String jsonStr) {
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    TableRow? header;

    if (decoded.containsKey('header')) {
      final headerList = (decoded['header'] as List<dynamic>).cast<dynamic>();
      header = TableRow.fromJson(headerList);
    }

    final rowsList = (decoded['rows'] as List<dynamic>);
    final dataRows = rowsList
        .map((r) => TableRow.fromJson((r as List<dynamic>)))
        .toList();

    return GherkinTable(dataRows, header);
  }

  /// Create a deep copy of this table.
  GherkinTable clone() {
    final copiedHeader = header?.clone();
    final copiedRows = rows.map((r) => r.clone()).toList();

    return GherkinTable(copiedRows, copiedHeader);
  }
}
