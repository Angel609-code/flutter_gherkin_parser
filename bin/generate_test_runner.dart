// bin/generate_test_runner.dart

import 'dart:io';
import 'dart:isolate';
import 'package:mustache_template/mustache_template.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gherkin_parser/utils/feature_parser.dart';

/// Entrypoint for the CLI that generates one test runner file per feature.
///
/// Usage:
///   dart run flutter_gherkin_parser:generate_test_runner [--config PATH]
///
/// If `--config PATH` is provided, the generated runners will import that
/// config file. Otherwise, they import the library’s default config.
Future<void> main(List<String> args) async {
  // Determine if the user provided a custom config path
  final rawConfigArgIndex = args.indexOf('--config');
  final configPath = (rawConfigArgIndex >= 0 && rawConfigArgIndex + 1 < args.length)
      ? args[rawConfigArgIndex + 1]
      : null;

  // Require `--config PATH` and exit if missing
  if (configPath == null || configPath.trim().isEmpty) {
    stderr.writeln(
        'Error: `--config PATH` is required. '
            'Example: dart run flutter_gherkin_parser:generate_test_runner '
            '--config=integration_test/test_config.dart'
    );
    exit(1);
  }

  // Build the import line using the user‐supplied config (no default fallback)
  final configImport = "import '$configPath';";

  // Locate the current working directory, expecting `integration_test/features/`
  final cwd = Directory.current.path;
  final featuresDir = Directory(p.join(cwd, 'integration_test', 'features'));
  if (!featuresDir.existsSync()) {
    stdout.writeln('No `integration_test/features/` folder found under $cwd');
    exit(1);
  }

  // Prepare the output folder `integration_test/generated/`
  final generatedRoot = Directory(p.join(cwd, 'integration_test', 'generated'));
  if (!generatedRoot.existsSync()) {
    generatedRoot.createSync(recursive: true);
  }

  // Parse each `.feature` file under `integration_test/features/`
  final parser = FeatureParser();
  final featureFiles = featuresDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.feature'))
      .toList();

  // Resolve the Mustache template bundled in this package
  final templateUri = await Isolate.resolvePackageUri(
    Uri.parse('package:flutter_gherkin_parser/templates/test_runner_template.mustache'),
  );

  if (templateUri == null) {
    stderr.writeln(
      'Cannot resolve package URI for '
          '`package:flutter_gherkin_parser/templates/test_runner_template.mustache`',
    );
    exit(2);
  }

  final templateFile = File.fromUri(templateUri);
  if (!templateFile.existsSync()) {
    stderr.writeln('Cannot find template at ${templateFile.path}');
    exit(2);
  }

  final templateContent = templateFile.readAsStringSync();
  final template = Template(templateContent, htmlEscapeValues: false);

  // Generate one runner per feature, preserving subfolder structure
  for (final featureFile in featureFiles) {
    // Compute the feature’s path relative to `featuresDir`
    final relPath = p.relative(featureFile.path, from: featuresDir.path);
    final raw = featureFile.readAsStringSync();
    final feature = parser.parse(raw, relPath);

    // Reject any file that has more than one "Background:" line.
    final backgroundCount = RegExp(r'^\s*Background:', multiLine: true)
        .allMatches(raw)
        .length;

    if (backgroundCount > 1) {
      stderr.writeln(
          'Error: More than one Background section found in "${featureFile.path}".\n'
              'A feature file may have at most one Background block.'
      );
      exit(1);
    }

    // Prepare the scenarios list with `isLast` flag
    final scenarioMaps = <Map<String, dynamic>>[];
    for (var i = 0; i < feature.scenarios.length; i++) {
      final scenario = feature.scenarios[i];
      final isLast = i == feature.scenarios.length - 1;

      scenarioMaps.add({
        'name': scenario.name,
        'steps': scenario.steps.map((s) {
          return {'json': s.toString()};
        }).toList(),
        'isLast': isLast,
      });
    }

    // Prepare the data map for Mustache rendering
    final featureData = {
      'name': feature.name,
      'scenarios': scenarioMaps,
      'backgroundSteps': feature.background?.steps.map((s) {
        return { 'jsonStep': s.toString() };
      }).toList() ?? [],
      'hasBackgroundSteps': feature.background?.steps.isNotEmpty ?? false,
    };

    final data = {
      'features': [featureData],
      'configImport': configImport,
    };

    final rendered = template.renderString(data);

    // Remove `.feature` extension and append `_test_runner.dart`
    final withoutExt = p.withoutExtension(relPath);
    final runnerRelPath = '${withoutExt}_test_runner.dart';

    // Build the full output path under `integration_test/generated/`
    final outFilePath = p.join(generatedRoot.path, runnerRelPath);
    final outFile = File(outFilePath);

    // Ensure the parent directory exists
    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }

    // Write the rendered Dart code
    outFile.writeAsStringSync(rendered);
    stdout.writeln('Generated $outFilePath');
  }

  stdout.writeln('\n✅  All runners generated successfully.');
}
