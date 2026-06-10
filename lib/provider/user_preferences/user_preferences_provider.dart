import 'package:drift/drift.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart' as paths;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide join;
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/models/metadata/market.dart';
import 'package:sonolyth/modules/settings/color_scheme_picker_dialog.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/utils/platform.dart';
import 'package:window_manager/window_manager.dart';
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
              ),
            );
      }

      state = await (db.select(db.preferencesTable)
            ..where((tbl) => tbl.id.equals(0)))
          .getSingle();

      final subscription = (db.select(db.preferencesTable)
            ..where((tbl) => tbl.id.equals(0)))
          .watchSingle()
          .listen((event) async {
        try {
          state = event;

          if (kIsDesktop) {
            await windowManager.setTitleBarStyle(
              state.systemTitleBar
                  ? TitleBarStyle.normal
                  : TitleBarStyle.hidden,
            );
          }

          await audioPlayer.setAudioNormalization(state.normalizeAudio);
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
    if (kIsAndroid) {
      final dir = await paths.getExternalStorageDirectory();
      return join(
          dir?.path ?? (await paths.getApplicationDocumentsDirectory()).path,
          "Downloads");
    }

    if (kIsMacOS) {
      return join((await paths.getLibraryDirectory()).path, "Caches");
    }

    return paths.getDownloadsDirectory().then((dir) {
      return join(dir!.path, "Sonolyth");
    });
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

  Future<void> setLayoutMode(LayoutMode mode) {
    return setData(PreferencesTableCompanion(layoutMode: Value(mode)));
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
}

final userPreferencesProvider =
    NotifierProvider<UserPreferencesNotifier, PreferencesTableData>(
  () => UserPreferencesNotifier(),
);
