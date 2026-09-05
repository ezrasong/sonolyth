import 'package:drift/drift.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart' as paths;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide join;
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/models/metadata/market.dart';
import 'package:sonolyth/models/playback/crossfade.dart';
import 'package:sonolyth/modules/settings/color_scheme_picker_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/utils/platform.dart';
import 'package:open_file/open_file.dart';

typedef UserPreferences = PreferencesTableData;

class UserPreferencesNotifier extends Notifier<PreferencesTableData> {
  @override
  build() {
    final db = ref.watch(databaseProvider);

    (db.select(db.preferencesTable)..where((tbl) => tbl.id.equals(0)))
        .getSingleOrNull()
        .then((result) async {
      if (result == null) {
        await db.into(db.preferencesTable).insert(
              PreferencesTableCompanion.insert(
                id: const Value(0),
                downloadLocation: Value(await _getDefaultDownloadDirectory()),
                // Default streaming engine: NewPipe everywhere it's supported
                // (iOS has no NewPipe extractor, so it stays on YouTubeExplode).
                youtubeClientEngine: Value(
                  kIsIOS
                      ? YoutubeClientEngine.youtubeExplode
                      : YoutubeClientEngine.newPipe,
                ),
              ),
            );
      }

      state = await (db.select(db.preferencesTable)
            ..where((tbl) => tbl.id.equals(0)))
          .getSingle();

      await _migrateToZenithAccent(db);

      final subscription = (db.select(db.preferencesTable)
            ..where((tbl) => tbl.id.equals(0)))
          .watchSingle()
          .listen((event) async {
        try {
          state = event;

          await audioPlayer.setAudioNormalization(state.normalizeAudio);
          // Crossfade is owned by the player, not the DB row: re-apply it on
          // every preferences emission so a launch (and a change made from
          // another surface) reaches the engine.
          await audioPlayer.setCrossfadeDuration(
            Duration(seconds: state.crossfadeDuration),
          );
          await audioPlayer.setCrossfadeCurve(state.crossfadeCurve);
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      });

      ref.onDispose(() {
        subscription.cancel();
      });
    });

    return PreferencesTable.defaults();
  }

  Future<String> _getDefaultDownloadDirectory() async {
    final dir = await paths.getExternalStorageDirectory();
    return join(
        dir?.path ?? (await paths.getApplicationDocumentsDirectory()).path,
        "Downloads");
  }

  Future<void> setData(PreferencesTableCompanion data) async {
    final db = ref.read(databaseProvider);

    final query = db.update(db.preferencesTable)..where((t) => t.id.equals(0));

    final previous = state;
    state = state.copyWithCompanion(data);

    try {
      await query.write(data);
    } catch (e, stack) {
      state = previous;
      AppLogger.reportError(e, stack);
      rethrow;
    }
  }

  Future<void> reset() async {
    final db = ref.read(databaseProvider);

    final query = db.update(db.preferencesTable);

    await query.replace(PreferencesTableCompanion.insert(id: const Value(0)));
  }

  static Future<String> getMusicCacheDir() async {
    if (kIsAndroid) {
      final dir =
          await paths.getExternalCacheDirectories().then((dirs) => dirs!.first);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return join(dir.path, 'Cached Tracks');
    }

    final dir = await paths.getApplicationCacheDirectory();
    return join(dir.path, 'cached_tracks');
  }

  Future<void> openCacheFolder() async {
    try {
      final filePath = await getMusicCacheDir();

      await OpenFile.open(filePath);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return setData(PreferencesTableCompanion(themeMode: Value(mode)));
  }

  Future<void> setRecommendationMarket(Market country) {
    return setData(PreferencesTableCompanion(market: Value(country)));
  }

  /// One-time move to the Proxima Dark Zenith accent scheme.
  ///
  /// Zenith is the app's identity but it didn't exist as a selectable scheme
  /// before, so every stored value on an existing install predates it and is
  /// really "never chosen". Rewrite it once, guarded by a flag, so the app
  /// looks like itself after an update — and so a user who later picks a
  /// different scheme keeps that choice.
  Future<void> _migrateToZenithAccent(AppDatabase db) async {
    const flag = "zenith-accent-migrated";
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(flag) == true) return;
      await preferences.setBool(flag, true);
      if (state.accentColorScheme.name == "zenith") return;
      await setAccentColorScheme(
        const SonolythColor(0xffffffff, name: "zenith"),
      );
    } catch (_) {
      // A failed migration just leaves the previous accent in place.
    }
  }

  Future<void> setAccentColorScheme(SonolythColor color) {
    return setData(PreferencesTableCompanion(accentColorScheme: Value(color)));
  }

  Future<void> setAlbumColorSync(bool sync) {
    return setData(PreferencesTableCompanion(albumColorSync: Value(sync)));

    // if (!sync) {
    //   ref.read(paletteProvider.notifier).state = null;
    // } else {
    //   ref.read(audioPlayerStreamListenersProvider).updatePalette();
    // }
  }

  Future<void> setCheckUpdate(bool check) {
    return setData(PreferencesTableCompanion(checkUpdate: Value(check)));
  }

  Future<void> setDownloadLocation(String downloadDir) {
    if (downloadDir.isEmpty) return Future.value();
    return setData(
      PreferencesTableCompanion(downloadLocation: Value(downloadDir)),
    );
  }

  Future<void> setLocalLibraryLocation(List<String> localLibraryDirs) {
    //if (localLibraryDir.isEmpty) return;
    return setData(
      PreferencesTableCompanion(
        localLibraryLocation: Value(localLibraryDirs),
      ),
    );
  }

  Future<void> setCloseBehavior(CloseBehavior behavior) {
    return setData(PreferencesTableCompanion(closeBehavior: Value(behavior)));
  }

  Future<void> setShowSystemTrayIcon(bool show) {
    return setData(PreferencesTableCompanion(showSystemTrayIcon: Value(show)));
  }

  Future<void> setLocale(Locale locale) {
    return setData(PreferencesTableCompanion(locale: Value(locale)));
  }

  Future<void> setSearchMode(SearchMode mode) {
    return setData(PreferencesTableCompanion(searchMode: Value(mode)));
  }

  Future<void> setSkipNonMusic(bool skip) {
    return setData(PreferencesTableCompanion(skipNonMusic: Value(skip)));
  }

  Future<void> setYoutubeClientEngine(YoutubeClientEngine engine) {
    return setData(
      PreferencesTableCompanion(youtubeClientEngine: Value(engine)),
    );
  }

  Future<void> setSystemTitleBar(bool isSystemTitleBar) {
    return setData(
      PreferencesTableCompanion(
        systemTitleBar: Value(isSystemTitleBar),
      ),
    );
  }

  Future<void> setDiscordPresence(bool discordPresence) {
    return setData(
      PreferencesTableCompanion(discordPresence: Value(discordPresence)),
    );
  }

  Future<void> setAmoledDarkTheme(bool isAmoled) {
    return setData(PreferencesTableCompanion(amoledDarkTheme: Value(isAmoled)));
  }

  Future<void> setNormalizeAudio(bool normalize) {
    final result = setData(
      PreferencesTableCompanion(normalizeAudio: Value(normalize)),
    );
    audioPlayer.setAudioNormalization(normalize);
    return result;
  }

  Future<void> setEndlessPlayback(bool endless) {
    return setData(PreferencesTableCompanion(endlessPlayback: Value(endless)));
  }

  Future<void> setEnableConnect(bool enable) {
    return setData(PreferencesTableCompanion(enableConnect: Value(enable)));
  }

  Future<void> setConnectPort(int port) {
    assert(
      port >= -1 && port <= 65535,
      "Port must be between -1 and 65535, got $port",
    );
    return setData(PreferencesTableCompanion(connectPort: Value(port)));
  }

  Future<void> setCacheMusic(bool cache) {
    return setData(PreferencesTableCompanion(cacheMusic: Value(cache)));
  }

  /// Seconds of overlap between tracks; 0 turns crossfading off.
  Future<void> setCrossfadeDuration(int seconds) {
    assert(
      seconds >= 0 && seconds <= maxCrossfadeSeconds,
      "Crossfade must be between 0 and $maxCrossfadeSeconds seconds",
    );
    final result = setData(
      PreferencesTableCompanion(crossfadeDuration: Value(seconds)),
    );
    audioPlayer.setCrossfadeDuration(Duration(seconds: seconds));
    return result;
  }

  Future<void> setCrossfadeCurve(CrossfadeCurve curve) {
    final result = setData(
      PreferencesTableCompanion(crossfadeCurve: Value(curve)),
    );
    audioPlayer.setCrossfadeCurve(curve);
    return result;
  }
}

/// Upper bound of the crossfade setting, matching what streaming apps offer.
const maxCrossfadeSeconds = 12;

final userPreferencesProvider =
    NotifierProvider<UserPreferencesNotifier, PreferencesTableData>(
  () => UserPreferencesNotifier(),
);
