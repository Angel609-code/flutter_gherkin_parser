import 'dart:convert' show jsonDecode, jsonEncode;

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
