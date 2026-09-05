// Re-applies the one hand patch that `drift_dev schema generate` discards.
//
// Run it immediately after regenerating the drift schema snapshots:
//
//   dart run drift_dev schema generate drift_schemas/app_db \
//       test/drift/app_db/generated/
//   dart run tool/freeze_schema_enums.dart
//
// WHY. drift emits historical column defaults as live references to the app's
// enums, e.g. `Constant(AudioSource.youtube.name)`. A schema snapshot is frozen
// history; those enums are not. `AudioSource`, `SourceQualities`,
// `SourceCodecs`, `SearchMode` and `YoutubeClientEngine` went away with the
// lossless-only conversion, and `Market` / `CloseBehavior` / `LayoutMode` /
// `ThemeMode` are never imported into the snapshots at all — the generated
// files import only `package:drift/drift.dart`. So the snapshots do not
// compile as generated, and `test/drift/app_db/migration_test.dart` fails to
// load, taking the only proof of the migrations with it.
//
// The patch is mechanical and lossless: `Constant(AudioSource.youtube.name)`
// *is* `Constant('youtube')`, by the definition of `EnumName.name`. Freezing it
// makes the snapshots self-contained, so no future enum deletion can break
// them again.
//
// Idempotent: files already carrying the marker are skipped.
import 'dart:io';

const _generatedDir = 'test/drift/app_db/generated';
const _marker = '// HAND-PATCHED AFTER GENERATION';
const _anchor = '// ignore_for_file: type=lint\n';

final _enumDefault =
    RegExp(r"Constant\([A-Z][A-Za-z0-9_]*\.([A-Za-z0-9_]+)\.name\)");

const _noteShort = '$_marker: enum `Constant(X.y.name)` defaults were\n'
    '// frozen to string literals. See tool/freeze_schema_enums.dart for why.\n';

void main(List<String> args) {
  final dir = Directory(_generatedDir);
  if (!dir.existsSync()) {
    stderr.writeln('no $_generatedDir — run drift_dev schema generate first');
    exitCode = 1;
    return;
  }

  var totalFiles = 0;
  var totalDefaults = 0;

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final source = file.readAsStringSync();
    if (source.contains(_marker)) continue;

    var frozen = 0;
    final patched = source.replaceAllMapped(_enumDefault, (m) {
      frozen++;
      return "Constant('${m[1]}')";
    });
    if (frozen == 0) continue;

    if (!patched.contains(_anchor)) {
      stderr.writeln('${file.path}: no `$_anchor` anchor — patch by hand');
      exitCode = 1;
      continue;
    }
    file.writeAsStringSync(
      patched.replaceFirst(_anchor, '$_anchor$_noteShort'),
    );
    totalFiles++;
    totalDefaults += frozen;
    stdout.writeln('${_basename(file.path)}: $frozen defaults frozen');
  }

  stdout.writeln(
    totalFiles == 0
        ? 'nothing to do — snapshots already frozen'
        : 'froze $totalDefaults defaults across $totalFiles files',
  );
}

String _basename(String path) =>
    path.split(Platform.pathSeparator).last.split('/').last;
