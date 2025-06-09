import 'package:flutter_gherkin_parser/models/models.dart';
import 'package:flutter_gherkin_parser/utils/steps_keywords.dart';

class FeatureParser {
  Feature parse(String content, String featurePath) {
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
        feature = Feature(
          name: line.substring('Feature:'.length).trim(),
          uri: '/features/$featurePath',
          line: i + 1,
        );

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
        currentScenario = Scenario(
          name: line.substring('Scenario:'.length).trim(),
          line: i + 1,
        );

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
        final step = Step(
          text: stepText,
          line: i + 1,
        );

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
