import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter_gherkin_parser/utils/expression_evaluator.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gherkin_parser/utils/feature_parser.dart';

/// Entrypoint for the CLI that generates one test runner file per feature.
///
/// Usage:
///   dart run flutter_gherkin_parser:generate_test_runner
///     --config PATH
///     [--order none|alphabetically|basename]
Future<void> main(List<String> args) async {
  // Parse --config
  final rawConfigArgIndex = args.indexOf('--config');
  final configPath = (rawConfigArgIndex >= 0 && rawConfigArgIndex + 1 < args.length)
      ? args[rawConfigArgIndex + 1]
      : null;
  if (configPath == null || configPath.trim().isEmpty) {
    stderr.writeln(
        'Error: `--config PATH` is required. '
            'Example: dart run flutter_gherkin_parser:generate_test_runner '
            '--config=integration_test/test_config.dart'
    );
    exit(1);
  }
  final configImport = "import '$configPath';";

  // Parse --order (none, alphabetically, basename, reverse, random[:seed])
  String order = 'none';
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--order=')) {
      order = a.split('=')[1];
    } else if (a == '--order' && i + 1 < args.length) {
      order = args[++i];
    }
  }

  /// Parse --pattern (optional, as a Dart RegExp)
  String? patternArg;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--pattern=')) {
      patternArg = a.split('=')[1];
    } else if (a == '--pattern' && i + 1 < args.length) {
      patternArg = args[++i];
    }
  }

  /// parse --tags optional
  String? tagsArg;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--tags=')) {
      tagsArg = a.split('=')[1];
    } else if (a == '--tags' && i + 1 < args.length) {
      tagsArg = args[++i];
    }
  }

  TagExpr? tagFilter;

  if (tagsArg != null && tagsArg.trim().isNotEmpty) {
    tagFilter = parseTagExpression(tagsArg);
  }

  // Locate features directory
  final cwd = Directory.current.path;
  final featuresDir = Directory(p.join(cwd, 'integration_test', 'features'));
  if (!featuresDir.existsSync()) {
    stdout.writeln('No `integration_test/features/` folder found under $cwd');
    exit(1);
  }

  // Load template
  final parser = FeatureParser();
  List<File> featureFiles = featuresDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.feature'))
      .toList();

  if (patternArg != null && patternArg.isNotEmpty) {
    final regex = RegExp(patternArg);

    featureFiles = featureFiles.where((f) {
      // relative path, e.g. "foo/bar/a_test_xyz.feature"
      final relPath = p.relative(f.path, from: featuresDir.path);
      return regex.hasMatch(relPath);
    }).toList();

    if (featureFiles.isEmpty) {
      stderr.writeln(
          'No feature files matching pattern `$patternArg` under '
              '${featuresDir.path}'
      );
      exit(0);
    }
  }

  // Prepare generated/ folder
  final generatedRoot = Directory(p.join(cwd, 'integration_test', 'generated'));
  if (generatedRoot.existsSync()) {
    generatedRoot.deleteSync(recursive: true);
  }
  generatedRoot.createSync(recursive: true);

  final templateUri = await Isolate.resolvePackageUri(
    Uri.parse('package:flutter_gherkin_parser/templates/test_runner_template.mustache'),
  );
  if (templateUri == null) {
    stderr.writeln(
        'Cannot resolve package URI for '
            '`package:flutter_gherkin_parser/templates/test_runner_template.mustache`'
    );
    exit(2);
  }
  final templateFile = File.fromUri(templateUri);
  if (!templateFile.existsSync()) {
    stderr.writeln('Cannot find template at ${templateFile.path}');
    exit(2);
  }
  final template = Template(templateFile.readAsStringSync(), htmlEscapeValues: false);

  // Generate one runner per feature
  for (final featureFile in featureFiles) {
    final relPath = p.relative(featureFile.path, from: featuresDir.path);
    final raw = featureFile.readAsStringSync();
    final feature = parser.parse(raw, relPath);

    // If we have a tagFilter, prune scenarios (and skip if none remain)
    if (tagFilter != null) {
      // Keep only scenarios that match
      final kept = feature.scenarios.where((sc) {
        // combine feature+scenario tags
        final tags = {...feature.tags, ...sc.tags}.toSet();
        return tagFilter!.evaluate(tags);
      }).toList();

      if (kept.isEmpty) {
        stdout.writeln('Skipping feature `${feature.name}`—no scenarios match tags `$tagsArg`');
        continue; // skip generating this feature’s runner entirely
      }

      feature.scenarios
        ..clear()
        ..addAll(kept);
    }

    // Validate single Feature and at most one Background
    final featureCount = RegExp(r'^\s*Feature:', multiLine: true)
        .allMatches(raw).length;
    if (featureCount != 1) {
      stderr.writeln(
          'Error: Expected exactly one "Feature:" in "${featureFile.path}", '
              'but found $featureCount.'
      );
      exit(1);
    }
    final backgroundCount = RegExp(r'^\s*Background:', multiLine: true)
        .allMatches(raw).length;
    if (backgroundCount > 1) {
      stderr.writeln(
          'Error: More than one Background in "${featureFile.path}".'
      );
      exit(1);
    }

    // Build Mustache data
    final scenarioMaps = <Map<String,dynamic>>[];
    for (var i = 0; i < feature.scenarios.length; i++) {
      final scenario = feature.scenarios[i];
      scenarioMaps.add({
        'name': scenario.name,
        'line': scenario.line,
        'tags': scenario.tags.map((e) => "'$e'").toList(),
        'steps': scenario.steps.map((s) => {'json': s.toString()}).toList(),
        'isLast': i == feature.scenarios.length - 1,
      });
    }

    final featureData = {
      'name': feature.name,
      'uri': feature.uri,
      'line': feature.line,
      'tags': feature.tags.map((e) => "'$e'").toList(),
      'scenarios': scenarioMaps,
      'backgroundSteps': feature.background?.steps
          .map((s) => {'jsonStep': s.toString()})
          .toList() ?? [],
      'hasBackgroundSteps': feature.background?.steps.isNotEmpty ?? false,
    };

    final rendered = template.renderString({
      'features': [featureData],
      'configImport': configImport,
    });

    // Write runner file
    final withoutExt = p.withoutExtension(relPath);
    final outFilePath = p.join(
        generatedRoot.path,
        '${withoutExt}_test_runner.dart'
    );
    final outFile = File(outFilePath);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(rendered);
    stdout.writeln('Generated $outFilePath');
  }

  // Generate master runner
  final genDir = Directory('integration_test/generated');
  List<File> allFiles = genDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  // Apply ordering
  switch (order) {
    case 'alphabetically':
      allFiles.sort((a, b) => a.path.compareTo(b.path));
      break;
    case 'basename':
      allFiles.sort((a, b) {
        final na = p.basenameWithoutExtension(a.path);
        final nb = p.basenameWithoutExtension(b.path);
        return na.compareTo(nb);
      });
      break;
    case 'random':
    case var s when s.startsWith('random:'):
    // random[:seed]
      final parts = order.split(':');
      final rng = (parts.length == 2 && int.tryParse(parts[1]) != null)
          ? Random(int.parse(parts[1]))
          : Random();
      allFiles.shuffle(rng);
      break;
    case 'reverse':
      allFiles = allFiles.reversed.toList();
      break;
    case 'none':
    default:
    // leave in filesystem discovery order
      break;
  }

  if (allFiles.isEmpty) {
    stderr.writeln('No .dart files found under integration_test/generated/.');
    exit(0);
  }

  // Build import and call lists
  final basenameCount = <String,int>{};
  for (var file in allFiles) {
    final base = p.basenameWithoutExtension(p.relative(file.path, from: 'integration_test'));
    basenameCount[base] = (basenameCount[base] ?? 0) + 1;
  }
  final importLines = <String>[];
  final callLines = <String>[];
  final usedSoFar = <String,int>{};

  for (var file in allFiles) {
    final rel = p.relative(file.path, from: 'integration_test');
    final base = p.basenameWithoutExtension(rel);
    final cnt = basenameCount[base]!;
    final idx = (usedSoFar[base] ?? 0) + 1;
    usedSoFar[base] = idx;
    final alias = cnt > 1 ? '${base}_$idx' : base;
    importLines.add("import '$rel' as $alias;");
    callLines.add('  $alias.main();');
  }

  // Write master runner
  final buffer = StringBuffer()
    ..writeln('// DO NOT EDIT MANUALLY. Generated by flutter_gherkin_parser.')
    ..writeln()
    ..writeln("import 'package:flutter_gherkin_parser/integration_test_helper.dart';")
    ..writeln(configImport)
    ..writeln();
  importLines.forEach(buffer.writeln);
  buffer
    ..writeln()
    ..writeln('void main() {')
    ..writeln('  IntegrationTestHelper(config: config);')
    ..writeln();
  callLines.forEach(buffer.writeln);
  buffer.writeln('}');

  final outFile = File('integration_test/all_integration_tests.dart');
  outFile.createSync(recursive: true);
  outFile.writeAsStringSync(buffer.toString());

  stdout.writeln(
      'Generated integration_test/all_integration_tests.dart '
          'with ${allFiles.length} runners.'
  );
  stdout.writeln('\n✅  All runners generated successfully.');
}
