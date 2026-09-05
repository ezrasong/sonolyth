// Proof that the drift migrations actually run. Two layers:
//
//  * the ladder — every from/to pair across all 13 schema versions is migrated
//    and the resulting schema compared against the recorded snapshot;
//  * one data-integrity test for **10 -> 12**, the pair that shipped without
//    ever being exercised against a populated database (CONTEXT §9.6);
//  * one for **12 -> 13**, which de-duplicates the match cache before putting
//    `uniq_track_match` back — the step that would silently do nothing if the
//    de-duplication were wrong or ran in the wrong order.
//
// The snapshots under `generated/` are HAND-PATCHED after generation — see
// `tool/freeze_schema_enums.dart`. Regenerating without re-running that tool
// puts this file back to "fails to load", which is how the 10 -> 12 migration
// went unverified in the first place.
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:test/test.dart';

import 'generated/schema.dart';
import 'generated/schema_v10.dart' as v10;
import 'generated/schema_v12.dart' as v12;
import 'generated/schema_v13.dart' as v13;

/// Columns whose SQL `DEFAULT` clause differs between a database that REACHED a
/// version by migrating and one freshly created at that version.
///
/// Each of these is a Dart column default that was edited without bumping the
/// schema version, so the recorded snapshot describes only the fresh-install
/// shape:
///
/// | column | migrated install | fresh install | changed by |
/// | --- | --- | --- | --- |
/// | `preferences_table.accent_color_scheme` | `android:…` / `Orange:…` / `Slate:…` | `zenith:0xffffffff` | the Zenith conversion |
/// | `preferences_table.theme_mode` | `system` | `dark` | the Zenith conversion |
/// | `source_match_table.source_type` | `youtube` | *(no default)* | the YouTube removal |
/// | `plugins_table.plugin_api_version`, `metadata_plugins_table.plugin_api_version` | *(no default)* | `1.0.0` / `2.0.0` | the plugin API bumps |
///
/// **This is tolerated, not endorsed.** A `DEFAULT` only applies to inserts that
/// omit the column, and every one of these columns is written explicitly by a
/// row that already exists on an upgraded install, so nothing observable
/// changes. Aligning them properly costs a schema version whose entire content
/// would be a table rebuild with no user-visible effect — a bad trade against
/// the migration risk. v13 landed for another reason (the unique index) and
/// these were still not worth a rebuild: a rebuild of `preferences_table`,
/// `source_match_table` and both plugin tables risks real user data to change
/// a clause that no insert in the app ever relies on.
///
/// The tolerance is deliberately narrow: the column must be named here AND the
/// two constraint strings must be identical once the `DEFAULT` clause is
/// removed. A `NOT NULL` that went missing, a changed type, an added or dropped
/// column or table still fails.
const _knownDefaultDrift = {
  'accent_color_scheme',
  'theme_mode',
  'source_type',
  'plugin_api_version',
};

final _defaultClause = RegExp(r"\s*DEFAULT\s+('(?:[^']|'')*'|\S+)");
final _notEqual =
    RegExp(r'^Not equal: `(.*)` \(expected\) and `(.*)` \(actual\)$');

/// The one structural divergence that is real, historical and unfixable.
///
/// `from9To10` drops the `uniq_track_match` unique index, but the v10 snapshot
/// still records it, because it was still declared in Dart at the time. So a
/// v10 database HAS the index if it was created fresh and LACKS it if it
/// arrived by migration — the "sourceMatchTable unique index" open item, now
/// with a reproduction.
///
/// It self-corrects: the index is gone from the v11 and v12 records, so every
/// ladder pair targeting 11 or 12 agrees. Nothing will target 10 again — the
/// app is on 13 — so this is dead history, tolerated for `toVersion == 10`
/// only.
///
/// The live half of it is closed: `from12To13` de-duplicates the table and
/// re-creates `uniq_track_match` over `(track_id, source_type)`, the columns
/// that still exist. A v10 database created fresh carries an index of the same
/// name over the old three columns, which is why that step drops by name
/// first — so every ladder pair targeting 13 agrees with the v13 record no
/// matter which shape it started from.
const _uniqTrackMatchAtV10 = 'comparing uniq_track_match';
const _absentFromActual =
    'The actual schema does not contain anything with this name.';

/// Re-throws unless every difference drift reported is one of the two
/// documented, non-structural divergences above.
void _tolerateKnownDrift(Object error, int toVersion) {
  final text = error.toString();
  if (!text.startsWith('Schema does not match')) throw error;

  String? name;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line == 'Schema does not match' || line == 'columns:') continue;

    if (line == _absentFromActual) {
      if (toVersion == 10 && name == _uniqTrackMatchAtV10) continue;
      throw error;
    }

    final mismatch = _notEqual.firstMatch(line);
    if (mismatch == null) {
      // `some_table:`, `some_column:` or `comparing x:` — remember the deepest
      // name seen, which is what the line after it is about.
      if (line.endsWith(':')) {
        name = line.substring(0, line.length - 1);
        continue;
      }
      throw error; // an unrecognised line: do not guess, surface it.
    }

    if (!_knownDefaultDrift.contains(name)) throw error;
    final expected = mismatch.group(1)!.replaceAll(_defaultClause, '');
    final actual = mismatch.group(2)!.replaceAll(_defaultClause, '');
    if (expected != actual) throw error; // differs by more than the default.
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('schema ladder', () {
    // No data, just the schema: a quick way to catch a migration step that
    // does not produce the schema its snapshot says it should.
    final versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase.forTesting(schema.newConnection());
            try {
              await verifier.migrateAndValidate(db, toVersion);
            } catch (e) {
              _tolerateKnownDrift(e, toVersion);
            } finally {
              await db.close();
            }
          });
        }
      });
    }
  });

  test('10 -> 12 keeps user data and lands the new surface', () async {
    // 10 -> 11 adds the crossfade preference columns; 11 -> 12 creates
    // `track_trim`. Neither touches existing rows, and this is the test that
    // says so out loud: an install upgrading from 10 must keep its match
    // cache, blacklist and history, and pick up the new columns at their
    // defaults rather than nulls.
    final schema = await verifier.schemaAt(10);

    final oldDb = v10.DatabaseAtV10(schema.newConnection());
    await oldDb.customStatement(
      "INSERT INTO preferences_table (id) VALUES (0)",
    );
    await oldDb.customStatement(
      "INSERT INTO blacklist_table (name, element_type, element_id) "
      "VALUES ('Nickelback', 'artist', 'artist-1')",
    );
    await oldDb.customStatement(
      "INSERT INTO source_match_table (track_id, source_info, source_type) "
      "VALUES ('track-1', '{\"id\":\"abc\"}', 'qobuz')",
    );
    await oldDb.customStatement(
      "INSERT INTO history_table (type, item_id, data) "
      "VALUES ('track', 'track-1', '{}')",
    );
    await oldDb.close();

    final migrated = AppDatabase.forTesting(schema.newConnection());
    try {
      await verifier.migrateAndValidate(migrated, 12);
    } catch (e) {
      _tolerateKnownDrift(e, 12);
    } finally {
      await migrated.close();
    }

    final newDb = v12.DatabaseAtV12(schema.newConnection());

    Future<QueryRow> one(String sql) async =>
        (await newDb.customSelect(sql).get()).single;

    // The rows survived, verbatim.
    expect(
      (await one("SELECT name FROM blacklist_table")).read<String>('name'),
      'Nickelback',
    );
    final match = await one("SELECT * FROM source_match_table");
    expect(match.read<String>('track_id'), 'track-1');
    expect(match.read<String>('source_info'), '{"id":"abc"}');
    expect(match.read<String>('source_type'), 'qobuz');
    expect(
      (await one("SELECT item_id FROM history_table")).read<String>('item_id'),
      'track-1',
    );

    // The columns 10 -> 11 added exist on the pre-existing row and carry the
    // declared defaults — `addColumn` on a populated table is exactly where a
    // NOT NULL column with no default would have failed.
    final prefs = await one("SELECT * FROM preferences_table");
    expect(prefs.read<int>('crossfade_duration'), 0);
    expect(prefs.read<String>('crossfade_curve'), 'equalPower');

    // And the table 11 -> 12 created is present, empty and writable.
    expect(
      (await newDb
              .customSelect("SELECT COUNT(*) AS c FROM track_trim_table")
              .getSingle())
          .read<int>('c'),
      0,
    );
    await newDb.customStatement(
      "INSERT INTO track_trim_table (file_path, file_size, duration_ms) "
      "VALUES ('/music/a.flac', 1024, 200000)",
    );
    final trim = await one("SELECT * FROM track_trim_table");
    expect(trim.read<int>('lead_ms'), 0);
    expect(trim.read<int>('tail_ms'), 0);

    await newDb.close();
  });
  test('12 -> 13 de-duplicates the match cache and enforces it from then on',
      () async {
    // `from9To10` dropped `uniq_track_match` and nothing replaced it, so
    // between schema 10 and 13 the "one match per (track, source)" rule was
    // enforced only by the writers. Any pair that raced — or predates the
    // transactions that narrowed the window — is still in the table, and
    // `CREATE UNIQUE INDEX` over it would throw. This is the test that says
    // the step de-duplicates first, keeps the newest row, and leaves an index
    // that actually rejects the next duplicate.
    final schema = await verifier.schemaAt(12);

    final oldDb = v12.DatabaseAtV12(schema.newConnection());
    // Three rows for one (track, source): the two older ones are the damage.
    await oldDb.customStatement(
      "INSERT INTO source_match_table "
      "(track_id, source_info, source_type, created_at) VALUES "
      "('track-1', '{\"id\":\"oldest\"}', 'lossless', 1), "
      "('track-1', '{\"id\":\"middle\"}', 'lossless', 2), "
      "('track-1', '{\"id\":\"newest\"}', 'lossless', 3)",
    );
    // A different source for the same track, and a different track: both are
    // distinct keys and must survive untouched.
    await oldDb.customStatement(
      "INSERT INTO source_match_table (track_id, source_info, source_type) "
      "VALUES ('track-1', '{\"id\":\"other-source\"}', 'local')",
    );
    await oldDb.customStatement(
      "INSERT INTO source_match_table (track_id, source_info, source_type) "
      "VALUES ('track-2', '{\"id\":\"untouched\"}', 'lossless')",
    );
    await oldDb.close();

    final migrated = AppDatabase.forTesting(schema.newConnection());
    try {
      await verifier.migrateAndValidate(migrated, 13);
    } catch (e) {
      _tolerateKnownDrift(e, 13);
    } finally {
      await migrated.close();
    }

    final newDb = v13.DatabaseAtV13(schema.newConnection());

    // The duplicates are gone and the row that survived is the newest one —
    // dropping the wrong row would silently downgrade a re-matched track back
    // to a match the app had already replaced.
    final kept = await newDb
        .customSelect(
          "SELECT source_info FROM source_match_table "
          "WHERE track_id = 'track-1' AND source_type = 'lossless'",
        )
        .get();
    expect(kept, hasLength(1));
    expect(kept.single.read<String>('source_info'), '{"id":"newest"}');

    // Distinct keys were not collateral damage.
    expect(
      (await newDb
              .customSelect("SELECT COUNT(*) AS c FROM source_match_table")
              .getSingle())
          .read<int>('c'),
      3,
    );

    // And the index is real: a second row for a key that already exists is
    // rejected by sqlite, not by the application.
    await expectLater(
      newDb.customStatement(
        "INSERT INTO source_match_table (track_id, source_info, source_type) "
        "VALUES ('track-2', '{\"id\":\"dupe\"}', 'lossless')",
      ),
      throwsA(predicate(
        (e) => e.toString().contains('UNIQUE constraint failed'),
        'a UNIQUE constraint violation',
      )),
    );

    // The upsert the writers use now takes the same path and does not throw.
    await newDb.customStatement(
      "INSERT INTO source_match_table (track_id, source_info, source_type) "
      "VALUES ('track-2', '{\"id\":\"replacement\"}', 'lossless') "
      "ON CONFLICT (track_id, source_type) "
      "DO UPDATE SET source_info = excluded.source_info",
    );
    expect(
      (await newDb
              .customSelect(
                "SELECT source_info FROM source_match_table "
                "WHERE track_id = 'track-2'",
              )
              .getSingle())
          .read<String>('source_info'),
      '{"id":"replacement"}',
    );

    await newDb.close();
  });
}
