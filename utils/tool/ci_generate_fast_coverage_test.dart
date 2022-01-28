// implement the "wrapper test pattern" from https://github.com/flutter/flutter/issues/90225

import 'dart:io';

const outputName = 'generated_fast_coverage_test.dart';

final partOf = RegExp(r"part of '.+\.dart';");
final mainFile = RegExp(r'main\w*\.dart$');
final ignoreFileComment = RegExp(r'//\s*fast-coverage-ignore');

void main() {
  final libDir =
      Directory.fromUri(Uri.directory('${Directory.current.path}/lib'));
  final testDir =
      Directory.fromUri(Uri.directory('${Directory.current.path}/test'));
  const packageName = 'coverage_issue';
  final output = StringBuffer()..writeln('// ignore_for_file: unused_import');
  final main = StringBuffer()..writeln('void main() {');

  // import all relevant dart files in lib/ so that coverage info is captured for unused files
  // see: https://github.com/flutter/flutter/issues/27997
  final libFiles = libDir //
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !file.path.endsWith('.g.dart'))
      .where((file) => !file.path.endsWith('/generated_plugin_registrant.dart'))
      .where((file) => !file.path.contains('/generated/'))
      .where((file) => !file.path.contains(mainFile))
      .toList()
    ..sort(compareFiles);

  for (final libFile in libFiles) {
    final content = libFile.readAsStringSync();
    if (content.contains(partOf) || content.contains(ignoreFileComment)) {
      // can't import files using "part of"
      continue;
    }

    output.writeln(
      "import 'package:$packageName/${libFile.path.substring(libDir.path.length)}';",
    );
  }

  output.writeln();

  final testFiles = testDir //
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_test.dart'))
      .where((file) => !file.path.endsWith(outputName))
      .where((file) => !file.path.endsWith('ensure_build_test.dart'))
      .where((file) => !file.path.endsWith('extension_l10n_test.dart'))
      .where((file) => !file.path.endsWith('flipped_switcher_test.dart'))
      .where(
        (file) => !file.path.endsWith('ci_generate_fast_coverage_test.dart'),
      )
      .toList()
    ..sort(compareFiles);

  for (final testFile in testFiles) {
    final relativePath =
        '../../test/${testFile.path.substring(testDir.path.length)}';
    final alias = testFile.uri.pathSegments.last.replaceFirst('.dart', '');
    output.writeln("import '$relativePath' as $alias;");
    main.writeln('  $alias.main();');
  }

  output //
    ..writeln()
    ..write(main)
    ..writeln('}');
  final uri = Uri.file('${Directory.current.path}/utils/tool/$outputName');
  File.fromUri(uri).writeAsStringSync(
    output.toString(),
    flush: true,
  );
}

int compareFiles(File a, File b) {
  return a.path.compareTo(b.path);
}
