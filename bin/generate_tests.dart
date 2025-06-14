import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter_gherkin_parser/utils/expression_evaluator.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gherkin_parser/utils/feature_parser.dart';

Future<void> main(List<String> args) async {
  final cwd = Directory.current.path;

  final configArgIndex = args.indexOf('--config');
  final configPath = (configArgIndex >= 0 && configArgIndex + 1 < args.length)
      ? args[configArgIndex + 1]
      : null;

  if (configPath == null || configPath.trim().isEmpty) {
    stderr.writeln('Error: --config <file> is required');
    exit(1);
  }

  final configFile = File(p.join(cwd, 'integration_test', configPath));
  if (!configFile.existsSync()) {
    stderr.writeln('Error: Cannot find config at integration_test/$configPath');
    exit(1);
  }

  String order = 'none';
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--order=')) {
      order = a.split('=')[1];
    } else if (a == '--order' && i + 1 < args.length) {
      order = args[++i];
    }
  }

  String? patternArg;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--pattern=')) {
      patternArg = a.split('=')[1];
    } else if (a == '--pattern' && i + 1 < args.length) {
      patternArg = args[++i];
    }
  }

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

  final featuresDir = Directory(p.join(cwd, 'integration_test', 'features'));
  if (!featuresDir.existsSync()) {
    stdout.writeln('No integration_test/features folder found under $cwd');
    exit(1);
  }

  final parser = FeatureParser();
  List<File> featureFiles = featuresDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.feature'))
      .toList();

  if (patternArg != null && patternArg.isNotEmpty) {
    final regex = RegExp(patternArg);
    featureFiles = featureFiles.where((f) {
      final relPath = p.relative(f.path, from: featuresDir.path);
      return regex.hasMatch(relPath);
    }).toList();

    if (featureFiles.isEmpty) {
      stderr.writeln('No feature files matching pattern $patternArg');
      exit(0);
    }
  }

  final generatedRoot = Directory(p.join(cwd, 'integration_test', 'generated'));
  if (generatedRoot.existsSync()) {
    generatedRoot.deleteSync(recursive: true);
  }
  generatedRoot.createSync(recursive: true);

  final templateUri = await Isolate.resolvePackageUri(
    Uri.parse('package:flutter_gherkin_parser/templates/test_runner_template.mustache'),
  );
  if (templateUri == null) {
    stderr.writeln('Cannot resolve template URI');
    exit(2);
  }
  final templateFile = File.fromUri(templateUri);
  if (!templateFile.existsSync()) {
    stderr.writeln('Cannot find template at ${templateFile.path}');
    exit(2);
  }
  final template = Template(templateFile.readAsStringSync(), htmlEscapeValues: false);

  for (final featureFile in featureFiles) {
    final relPath = p.relative(featureFile.path, from: featuresDir.path);
    final raw = featureFile.readAsStringSync();
    final feature = parser.parse(raw, relPath);

    if (tagFilter != null) {
      final kept = feature.scenarios.where((sc) {
        final tags = {...feature.tags, ...sc.tags}.toSet();
        return tagFilter!.evaluate(tags);
      }).toList();

      if (kept.isEmpty) {
        stdout.writeln('Skipping ${feature.name}, no scenarios match $tagsArg');
        continue;
      }
      feature.scenarios
        ..clear()
        ..addAll(kept);
    }

    final featureCount = RegExp(r'^\s*Feature:', multiLine: true).allMatches(raw).length;
    if (featureCount != 1) {
      stderr.writeln('Error: Expected one Feature in ${featureFile.path}');
      exit(1);
    }
    final backgroundCount = RegExp(r'^\s*Background:', multiLine: true).allMatches(raw).length;
    if (backgroundCount > 1) {
      stderr.writeln('Error: More than one Background in ${featureFile.path}');
      exit(1);
    }

    final scenarioMaps = <Map<String, dynamic>>[];
    for (var i = 0; i < feature.scenarios.length; i++) {
      final sc = feature.scenarios[i];
      scenarioMaps.add({
        'name': sc.name,
        'line': sc.line,
        'tags': sc.tags.map((e) => "'$e'").toList(),
        'steps': sc.steps.map((s) => {'json': s.toString()}).toList(),
        'isLast': i == feature.scenarios.length - 1,
      });
    }

    final featureData = {
      'name': feature.name,
      'uri': feature.uri,
      'line': feature.line,
      'tags': feature.tags.map((e) => "'$e'").toList(),
      'scenarios': scenarioMaps,
      'backgroundSteps': feature.background?.steps.map((s) => {'jsonStep': s.toString()}).toList() ?? [],
      'hasBackgroundSteps': feature.background?.steps.isNotEmpty ?? false,
    };

    final runnerDir = Directory(p.join(generatedRoot.path, p.dirname(relPath)));
    runnerDir.createSync(recursive: true);

    // compute import path for the real config
    final configImportPath = p.relative(
      p.join(cwd, 'integration_test', configPath),
      from: runnerDir.path,
    );

    final rendered = template.renderString({
      'features': [featureData],
      'configImport': "import '$configImportPath';",
    });

    final outFilePath = p.join(
      generatedRoot.path,
      '${p.withoutExtension(relPath)}.dart',
    );

    File(outFilePath)
      ..createSync(recursive: true)
      ..writeAsStringSync(rendered);

    stdout.writeln('Generated $outFilePath');
  }

  final genDir = Directory(p.join(cwd, 'integration_test', 'generated'));
  List<File> allFiles = genDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

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
    case var s when s.startsWith('random'):
      final parts = order.split(':');
      final rng = (parts.length == 2 && int.tryParse(parts[1]) != null)
          ? Random(int.parse(parts[1]))
          : Random();
      allFiles.shuffle(rng);
      break;
    case 'reverse':
      allFiles = allFiles.reversed.toList();
      break;
    default:
      break;
  }

  if (allFiles.isEmpty) {
    stderr.writeln('No .dart files in generated');
    exit(0);
  }

  final basenameCount = <String, int>{};
  for (var file in allFiles) {
    final base = p.basenameWithoutExtension(p.relative(file.path, from: 'integration_test'));
    basenameCount[base] = (basenameCount[base] ?? 0) + 1;
  }

  final importLines = <String>[];
  final callLines = <String>[];
  final usedSoFar = <String, int>{};

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

  final masterConfigImport = "import '${p.relative(
    p.join(cwd, 'integration_test', configPath),
    from: p.join(cwd, 'integration_test'),
  )}';";

  final buffer = StringBuffer()
    ..writeln('// DO NOT EDIT MANUALLY. Generated by flutter_gherkin_parser.')
    ..writeln("import 'package:flutter_gherkin_parser/integration_test_helper.dart';")
    ..writeln(masterConfigImport)
    ..writeln();

  importLines.forEach(buffer.writeln);
  buffer
    ..writeln()
    ..writeln('void main() {')
    ..writeln('  IntegrationTestHelper(config: config);')
    ..writeln();

  callLines.forEach(buffer.writeln);
  buffer.writeln('}');

  final masterFile = File(p.join(cwd, 'integration_test', 'all_integration_tests.dart'));
  masterFile
    ..createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  stdout.writeln('Generated integration_test/all_integration_tests.dart with ${allFiles.length} runners.');

  stdout.writeln('\n✅  All integration tests generated successfully.');
}
