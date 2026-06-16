import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:home_widget/home_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:media_kit/media_kit.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:sonolyth/collections/env.dart';
import 'package:sonolyth/collections/http-override.dart';
import 'package:sonolyth/collections/intents.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sonolyth/collections/routes.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/hooks/configurators/use_android_display_setup.dart';
import 'package:sonolyth/hooks/configurators/use_close_behavior.dart';
import 'package:sonolyth/hooks/configurators/use_deep_linking.dart';
import 'package:sonolyth/hooks/configurators/use_disable_battery_optimizations.dart';
import 'package:sonolyth/hooks/configurators/use_fix_window_stretching.dart';
import 'package:sonolyth/hooks/configurators/use_has_touch.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/modules/settings/color_scheme_picker_dialog.dart';
import 'package:sonolyth/provider/audio_player/audio_player_streams.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/provider/downloaded_tracks_provider.dart';
import 'package:sonolyth/provider/glance/glance.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/updater/update_checker.dart';
import 'package:sonolyth/provider/server/bonsoir.dart';
import 'package:sonolyth/provider/server/server.dart';
import 'package:sonolyth/provider/tray_manager/tray_manager.dart';
import 'package:sonolyth/l10n/l10n.dart';
import 'package:sonolyth/provider/connect/clients.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/android_system_accent.dart';
import 'package:sonolyth/services/cli/cli.dart';
import 'package:sonolyth/services/kv_store/encrypted_kv_store.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/wm_tools/wm_tools.dart';
import 'package:sonolyth/utils/migrations/sandbox.dart';
import 'package:sonolyth/utils/platform.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:window_manager/window_manager.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:yt_dlp_dart/yt_dlp_dart.dart';
import 'package:flutter_new_pipe_extractor/flutter_new_pipe_extractor.dart';

Future<void> main(List<String> rawArgs) async {
  if (rawArgs.contains("web_view_title_bar")) {
    WidgetsFlutterBinding.ensureInitialized();
    if (runWebViewTitleBarWidget(rawArgs)) {
      return;
    }
  }
  final arguments = await startCLI(rawArgs);
  AppLogger.initialize(arguments["verbose"]);

  AppLogger.runZoned(() async {
    WidgetsFlutterBinding.ensureInitialized();

    HttpOverrides.global = BadCertificateAllowlistOverrides();

    // await registerWindowsScheme("spotify");

    tz.initializeTimeZones();

    MediaKit.ensureInitialized();

    await migrateMacOsFromSandboxToNoSandbox();

    // High refresh rate + portrait lock moved to useAndroidDisplaySetup:
    // both need an attached activity, and when AudioService boots this
    // engine headlessly (media-button press after a process kill) they threw
    // noActivity here — aborting main() before runApp and leaving a cached
    // engine with no UI, which every later launch attached to as a
    // permanently black screen.
    if (kIsAndroid || kIsDesktop) {
      await NewPipeExtractor.init();
    }

    if (!kIsWeb) {
      MetadataGod.initialize();
    }

    await KVStoreService.initialize();

    if (kIsDesktop) {
      await windowManager.setPreventClose(true);
      await YtDlp.instance
          .setBinaryLocation(
            KVStoreService.getYoutubeEnginePath(YoutubeClientEngine.ytDlp) ??
                "yt-dlp${kIsWindows ? '.exe' : ''}",
          )
          .catchError((e, stack) => null);
    }

    if (kIsWindows) {
      await SMTCWindows.initialize();
    }

    await EncryptedKvStoreService.initialize();

    final database = AppDatabase();

    // One-time: drop audio-source matches picked by older rankings (v2 was
    // MV-biased; v3 added variant penalties for live/remix/cover uploads).
    if (KVStoreService.sharedPreferences.getBool('sourceMatchRankingV3') !=
        true) {
      await database.delete(database.sourceMatchTable).go();
      await KVStoreService.sharedPreferences
          .setBool('sourceMatchRankingV3', true);
    }

    // One-time: clear matches the old first-track prewarm may have pinned to a
    // lossy Piped source. Prewarming ran during the page-load request burst,
    // which rate-limited the Qobuz match and cached YouTube permanently — so
    // the first song always streamed via Piped. Re-resolving picks Qobuz first.
    if (KVStoreService.sharedPreferences.getBool('sourceMatchQobuzFirstV1') !=
        true) {
      await database.delete(database.sourceMatchTable).go();
      await KVStoreService.sharedPreferences
          .setBool('sourceMatchQobuzFirstV1', true);
    }

    if (kIsDesktop) {
      await localNotifier.setup(appName: "Sonolyth");
      await WindowManagerTools.initialize();
    }

    if (kIsIOS) {
      HomeWidget.setAppGroupId("group.spotube_home_player_widget");
    }

    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) => database),
        ],
        observers: const [
          AppLoggerProviderObserver(),
        ],
        child: const SonolythApp(),
      ),
    );
  });
}

class SonolythApp extends HookConsumerWidget {
  const SonolythApp({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final themeMode =
        ref.watch(userPreferencesProvider.select((s) => s.themeMode));
    final locale = ref.watch(userPreferencesProvider.select((s) => s.locale));
    final accentMaterialColor =
        ref.watch(userPreferencesProvider.select((s) => s.accentColorScheme));
    final accentColorSchemeName = accentMaterialColor.name == "Slate"
        ? "spotify"
        : accentMaterialColor.name.toLowerCase();
    final useAndroidSystemAccent =
        kIsAndroid && accentColorSchemeName == "android";
    final shadcnAccentColorSchemeName =
        useAndroidSystemAccent ? "android" : accentColorSchemeName;
    final effectiveThemeMode =
        themeMode == ThemeMode.system ? ThemeMode.dark : themeMode;
    final materialBrightness = switch (effectiveThemeMode) {
      ThemeMode.system => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };
    final router = useMemoized(() => AppRouter(ref), []);
    final hasTouchSupport = useHasTouch();
    final androidAccentColor = useFuture(
      useMemoized(AndroidSystemAccent.getColor, []),
    );
    final effectiveAccentColor = useAndroidSystemAccent
        ? androidAccentColor.data ??
            material.Color(accentMaterialColor.toARGB32())
        : material.Color(accentMaterialColor.toARGB32());

    // The shadcn color scheme is looked up by name; "android" was hardcoded to
    // violet, so the Material-You system accent never reached the bulk of the
    // UI (only Material widgets, via fromSeed below). Override the scheme's
    // primary with the real effective accent color so it actually applies.
    ColorScheme resolveColorScheme(ThemeMode mode) {
      final base = colorSchemeMap[shadcnAccentColorSchemeName]?.call(mode) ??
          LegacyColorSchemes.violet(mode);
      if (!useAndroidSystemAccent) return base;
      final onAccent = effectiveAccentColor.computeLuminance() > 0.5
          ? const Color(0xff000000)
          : const Color(0xffffffff);
      return base.copyWith(
        primary: () => effectiveAccentColor,
        primaryForeground: () => onAccent,
        ring: () => effectiveAccentColor,
      );
    }

    ref.listen(audioPlayerStreamListenersProvider, (_, __) {});
    // Load the downloaded-tracks registry up front so media construction can
    // route already-downloaded tracks to their local files.
    ref.listen(downloadedTracksProvider, (_, __) {});
    ref.listen(bonsoirProvider, (_, __) {});
    ref.listen(connectClientsProvider, (_, __) {});
    ref.listen(serverProvider, (_, __) {});
    ref.listen(trayManagerProvider, (_, __) {});
    ref.listen(metadataPluginsProvider, (_, __) {});
    ref.listen(metadataPluginProvider, (_, __) {});
    ref.listen(audioSourcePluginProvider, (_, __) {});
    ref.listen(metadataPluginUpdateCheckerProvider, (_, __) {});
    ref.listen(audioSourcePluginUpdateCheckerProvider, (_, __) {});

    useAndroidDisplaySetup();
    useFixWindowStretching();
    useDeepLinking(ref, router);
    useCloseBehavior(ref);
    useDisableBatteryOptimizations();

    useEffect(() {
      if (kIsMobile) {
        HomeWidget.registerInteractivityCallback(glanceBackgroundCallback);
      }

      return () {
        /// For enabling hot reload for audio player
        if (!kDebugMode) return;
        audioPlayer.dispose();
      };
    }, []);

    return ShadcnApp.router(
      supportedLocales: L10n.all,
      locale: locale.languageCode == "system" ? null : locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router.config(
        // First run lands on the getting-started flow (ending in the
        // provider sign-in) instead of an empty Home with no hint that a
        // login is needed.
        deepLinkBuilder: (deepLink) {
          if (!KVStoreService.doneGettingStarted) {
            return const DeepLink([GettingStartedRoute()]);
          }
          return deepLink;
        },
      ),
      debugShowCheckedModeBanner: false,
      title: 'Sonolyth',
      builder: (context, child) {
        child = ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: hasTouchSupport
                ? {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.invertedStylus,
                  }
                : null,
          ),
          child: child!,
        );

        if (kIsLinux) {
          child = DragToResizeArea(
            resizeEdgeSize: 2.5,
            child: child,
          );
        }

        return child;
      },
      scaling: const AdaptiveScaling(1),
      theme: ThemeData(
        radius: .5,
        iconTheme: const IconThemeProperties(),
        colorScheme: resolveColorScheme(ThemeMode.light),
        surfaceOpacity: 1,
        surfaceBlur: 0,
      ),
      darkTheme: ThemeData(
        radius: .5,
        iconTheme: const IconThemeProperties(),
        colorScheme: resolveColorScheme(ThemeMode.dark),
        surfaceOpacity: 1,
        surfaceBlur: 0,
      ),
      materialTheme: material.ThemeData(
        brightness: materialBrightness,
        scaffoldBackgroundColor: materialBrightness == Brightness.dark
            ? const material.Color(0xff121212)
            : const material.Color(0xfffafafa),
        canvasColor: materialBrightness == Brightness.dark
            ? const material.Color(0xff121212)
            : const material.Color(0xfffafafa),
        colorScheme: material.ColorScheme.fromSeed(
          seedColor: effectiveAccentColor,
          brightness: materialBrightness,
        ).copyWith(
          primary: effectiveAccentColor,
          surface: materialBrightness == Brightness.dark
              ? const material.Color(0xff181818)
              : const material.Color(0xffffffff),
        ),
        splashFactory: material.NoSplash.splashFactory,
        appBarTheme: const material.AppBarTheme(
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      themeMode: effectiveThemeMode,
      shortcuts: {
        ...WidgetsApp.defaultShortcuts.map((key, value) {
          return MapEntry(
            LogicalKeySet.fromSet(key.triggers?.toSet() ?? {}),
            value,
          );
        }),
        LogicalKeySet(LogicalKeyboardKey.space): PlayPauseIntent(ref),
        LogicalKeySet(LogicalKeyboardKey.comma, LogicalKeyboardKey.control):
            NavigationIntent(router, "/settings"),
        LogicalKeySet(
          LogicalKeyboardKey.digit1,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.browse),
        LogicalKeySet(
          LogicalKeyboardKey.digit2,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.search),
        LogicalKeySet(
          LogicalKeyboardKey.digit3,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.lyrics),
        LogicalKeySet(
          LogicalKeyboardKey.digit4,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.userPlaylists),
        LogicalKeySet(
          LogicalKeyboardKey.digit5,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.userArtists),
        LogicalKeySet(
          LogicalKeyboardKey.digit6,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.userAlbums),
        LogicalKeySet(
          LogicalKeyboardKey.digit7,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): HomeTabIntent(router, tab: HomeTabs.userDownloads),
        LogicalKeySet(
          LogicalKeyboardKey.keyW,
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
        ): CloseAppIntent(),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        PlayPauseIntent: PlayPauseAction(),
        NavigationIntent: NavigationAction(),
        HomeTabIntent: HomeTabAction(),
        CloseAppIntent: CloseAppAction(),
      },
    );
  }
}
