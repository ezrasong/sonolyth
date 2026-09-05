library database;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/remote.dart';
import 'package:encrypt/encrypt.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ThemeMode;
import 'package:sonolyth/models/database/database.steps.dart';
import 'package:sonolyth/models/lyrics.dart';
import 'package:sonolyth/models/metadata/market.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/models/playback/crossfade.dart';
import 'package:sonolyth/services/kv_store/encrypted_kv_store.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:flutter/widgets.dart' hide Table, Key, View;
import 'package:sonolyth/modules/settings/color_scheme_picker_dialog.dart';
import 'package:drift/native.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/youtube_engine/newpipe_engine.dart';
import 'package:sonolyth/services/youtube_engine/youtube_explode_engine.dart';
import 'package:sonolyth/services/youtube_engine/yt_dlp_engine.dart';
import 'package:sonolyth/utils/platform.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

part 'tables/authentication.dart';
part 'tables/blacklist.dart';
part 'tables/preferences.dart';
part 'tables/scrobbler.dart';
part 'tables/skip_segment.dart';
part 'tables/source_match.dart';
part 'tables/audio_player_state.dart';
part 'tables/history.dart';
part 'tables/lyrics.dart';
part 'tables/metadata_plugins.dart';
part 'tables/track_trim.dart';

part 'typeconverters/color.dart';
part 'typeconverters/locale.dart';
part 'typeconverters/string_list.dart';
part 'typeconverters/encrypted_text.dart';
part 'typeconverters/map.dart';
part 'typeconverters/map_list.dart';
part 'typeconverters/subtitle.dart';

@DriftDatabase(
  tables: [
    AuthenticationTable,
    BlacklistTable,
    PreferencesTable,
    ScrobblerTable,
    SkipSegmentTable,
    SourceMatchTable,
    AudioPlayerStateTable,
    HistoryTable,
    LyricsTable,
    PluginsTable,
    TrackTrimTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Opens the real schema and migrations over a caller-supplied executor.
  /// Exists so `test/drift/app_db/migration_test.dart` can run the migration
  /// ladder against an in-memory database — the default constructor always
  /// opens the on-device file, which is exactly what a migration test must not
  /// touch.
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: stepByStep(
        from1To2: (m, schema) async {
          // Add invidiousInstance column to preferences table
          await m.addColumn(
            schema.preferencesTable,
            schema.preferencesTable.invidiousInstance,
          );
        },
        from2To3: (m, schema) async {
          await m.addColumn(
            schema.preferencesTable,
            schema.preferencesTable.cacheMusic,
          );
        },
        from3To4: (m, schema) async {
          await m.addColumn(
            schema.preferencesTable,
            schema.preferencesTable.youtubeClientEngine,
          );
        },
        from4To5: (m, schema) async {
          final columnName = schema.preferencesTable.accentColorScheme
              .escapedNameFor(SqlDialect.sqlite);
          final columnNameOld =
              '"${schema.preferencesTable.accentColorScheme.name}_old"';
          final tableName = schema.preferencesTable.actualTableName;
          await customStatement(
            "ALTER TABLE $tableName "
            "RENAME COLUMN $columnName to $columnNameOld",
          );
          await customStatement(
            "ALTER TABLE $tableName "
            "ADD COLUMN $columnName TEXT NOT NULL DEFAULT 'android:0xff6750a4'",
          );
          await customStatement(
            "UPDATE $tableName "
            "SET $columnName = $columnNameOld",
          );
          await customStatement(
            "ALTER TABLE $tableName "
            "DROP COLUMN $columnNameOld",
          );
          await customStatement(
            "UPDATE $tableName "
            "SET $columnName = 'android:0xff6750a4' WHERE $columnName IN ('Blue:0xFF2196F3', 'Slate:0xff64748b', 'spotify:0xff1db954')",
          );
        },
        from5To6: (m, schema) async {
          try {
            await m.addColumn(
              schema.preferencesTable,
              schema.preferencesTable.connectPort,
            );
          } on DriftRemoteException catch (e) {
            // If the column already exists, ignore the error
            if (e.remoteCause !=
                'duplicate column name: ${schema.preferencesTable.connectPort.name}') {
              rethrow;
            }
          }
        },
        from6To7: (m, schema) async {
          await m.createTable(schema.metadataPluginsTable);
          await m.addColumn(
            schema.audioPlayerStateTable,
            schema.audioPlayerStateTable.currentIndex,
          );
          await m.addColumn(
            schema.audioPlayerStateTable,
            schema.audioPlayerStateTable.tracks,
          );
        },
        from7To8: (m, schema) async {
          await m
              .addColumn(
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.entryPoint,
          )
              .catchError((error, stackTrace) {
            // If the column already exists, ignore the error
            if (!error.toString().contains('duplicate column name')) {
              throw error;
            }
          });
          await m
              .addColumn(
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.apis,
          )
              .catchError((error, stackTrace) {
            // If the column already exists, ignore the error
            if (!error.toString().contains('duplicate column name')) {
              throw error;
            }
          });
          await m
              .addColumn(
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.abilities,
          )
              .catchError((error, stackTrace) {
            // If the column already exists, ignore the error
            if (!error.toString().contains('duplicate column name')) {
              throw error;
            }
          });
          await m
              .addColumn(
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.repository,
          )
              .catchError((error, stackTrace) {
            // If the column already exists, ignore the error
            if (!error.toString().contains('duplicate column name')) {
              throw error;
            }
          });
          await m
              .addColumn(
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.pluginApiVersion,
          )
              .catchError((error, stackTrace) {
            // If the column already exists, ignore the error
            if (!error.toString().contains('duplicate column name')) {
              throw error;
            }
          });
        },
        from8To9: (m, schema) async {
          await m
              .renameTable(schema.pluginsTable, "metadata_plugins_table")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .renameColumn(
                schema.pluginsTable,
                "selected",
                pluginsTable.selectedForMetadata,
              )
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .addColumn(
                schema.pluginsTable,
                pluginsTable.selectedForAudioSource,
              )
              .catchError((e, stack) => AppLogger.reportError(e, stack));
        },
        from9To10: (m, schema) async {
          await m
              .dropColumn(schema.preferencesTable, "piped_instance")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .dropColumn(schema.preferencesTable, "invidious_instance")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          // The v10 snapshot records preferences_table gaining
          // `audio_source_id` and losing four source/codec columns at this
          // step. It never did either, so an install that migrated 9 -> 10
          // has no `audio_source_id` at all and any full-row UPDATE against
          // it fails with `no such column`. Installs already past 10 are
          // repaired in `from11To12`; this keeps a v9 install from arriving
          // broken in the first place.
          await m
              .addColumn(
                schema.preferencesTable,
                schema.preferencesTable.audioSourceId,
              )
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          for (final dead in _preferencesColumnsDroppedAtV10) {
            await m
                .dropColumn(schema.preferencesTable, dead)
                .catchError((e, stack) => AppLogger.reportError(e, stack));
          }
          await m
              .addColumn(
                schema.sourceMatchTable,
                sourceMatchTable.sourceInfo,
              )
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await customStatement("DROP INDEX IF EXISTS uniq_track_match;")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .dropColumn(schema.sourceMatchTable, "source_id")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
        },
        from10To11: (m, schema) async {
          await m
              .addColumn(
                schema.preferencesTable,
                schema.preferencesTable.crossfadeDuration,
              )
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .addColumn(
                schema.preferencesTable,
                schema.preferencesTable.crossfadeCurve,
              )
              .catchError((e, stack) => AppLogger.reportError(e, stack));
        },
        from11To12: (m, schema) async {
          await m
              .createTable(schema.trackTrimTable)
              .catchError((e, stack) => AppLogger.reportError(e, stack));

          // Convergence repair for the `from9To10` defect above. Schema 11 and
          // 12 have not shipped, so every install still on 10 passes through
          // here exactly once. Guarded on the live column list rather than
          // let-it-throw, so a database that is already correct (any fresh
          // v10+ install) does no work and logs no errors.
          final columns = await _columnsOf("preferences_table");
          if (!columns.contains("audio_source_id")) {
            await m
                .addColumn(
                  schema.preferencesTable,
                  schema.preferencesTable.audioSourceId,
                )
                .catchError((e, stack) => AppLogger.reportError(e, stack));
          }
          for (final dead in _preferencesColumnsDroppedAtV10) {
            if (!columns.contains(dead)) continue;
            await m
                .dropColumn(schema.preferencesTable, dead)
                .catchError((e, stack) => AppLogger.reportError(e, stack));
          }
        },
        from12To13: (m, schema) async {
          // Re-declares `uniq_track_match`, the unique index `from9To10` had
          // to drop when `source_id` went away and nobody ever replaced. Until
          // now the "one match per (track, source)" rule lived only in the two
          // writers' delete-then-insert transactions, so any older duplicate —
          // or any pair that raced before those transactions existed — is
          // still sitting in the table.
          //
          // Order matters: de-duplicate first, or `CREATE UNIQUE INDEX`
          // throws and the index is silently never created.
          //
          // A database created fresh at v10 carries an index of the SAME NAME
          // over the old three columns (the v10 snapshot still recorded it),
          // so drop by name before creating.
          await customStatement("DROP INDEX IF EXISTS uniq_track_match;")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await customStatement(
            "DELETE FROM source_match_table WHERE id NOT IN ("
            "SELECT MAX(id) FROM source_match_table "
            "GROUP BY track_id, source_type)",
          ).catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .createIndex(schema.uniqTrackMatch)
              .catchError((e, stack) => AppLogger.reportError(e, stack));
        },
      ),
    );
  }

  /// The preferences columns the v10 schema record says went away with the
  /// audio-source rework. They are `NOT NULL` with defaults, so leaving them
  /// behind is survivable — but it leaves the table permanently different from
  /// its own recorded shape, which is how the missing `audio_source_id` stayed
  /// invisible.
  static const _preferencesColumnsDroppedAtV10 = [
    "audio_quality",
    "audio_source",
    "stream_music_codec",
    "download_music_codec",
  ];

  /// Live column names of [table], straight from sqlite. Used by migrations
  /// that have to repair a database whose actual shape is not knowable from
  /// its schema version alone.
  Future<Set<String>> _columnsOf(String table) async {
    final rows = await customSelect("PRAGMA table_info('$table')").get();
    return {for (final row in rows) row.read<String>("name")};
  }
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(join(dbFolder.path, 'db.sqlite'));

    // Also work around limitations on old Android versions
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Make sqlite3 pick a more suitable location for temporary files - the
    // one from the system may be inaccessible due to sandboxing.
    final cacheBase = (await getTemporaryDirectory()).path;
    // We can't access /tmp on Android, which sqlite3 would try by default.
    // Explicitly tell it about the correct temporary directory.
    sqlite3.tempDirectory = cacheBase;

    return NativeDatabase.createInBackground(file);
  });
}
