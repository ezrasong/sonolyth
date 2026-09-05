import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:home_widget/home_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:sonolyth/collections/http-override.dart';
import 'package:sonolyth/collections/intents.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sonolyth/collections/routes.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/hooks/configurators/use_android_display_setup.dart';
import 'package:sonolyth/hooks/configurators/use_disable_battery_optimizations.dart';
import 'package:sonolyth/hooks/configurators/use_has_touch.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/modules/settings/color_scheme_picker_dialog.dart';
import 'package:sonolyth/provider/audio_player/audio_player_streams.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/provider/history/retention.dart';
import 'package:sonolyth/provider/audio_player/track_trim.dart';
import 'package:sonolyth/provider/downloaded_tracks_provider.dart';
import 'package:sonolyth/provider/glance/glance.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/updater/update_checker.dart';
import 'package:sonolyth/provider/server/bonsoir.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/provider/server/server.dart';
import 'package:sonolyth/l10n/l10n.dart';
import 'package:sonolyth/provider/connect/clients.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/android_system_accent.dart';
import 'package:sonolyth/services/cli/cli.dart';
import 'package:sonolyth/services/kv_store/encrypted_kv_store.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/sourced_track/qobuz_audio_source.dart';
import 'package:sonolyth/services/sourced_track/tidal_audio_source.dart';
import 'package:sonolyth/utils/platform.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_new_pipe_extractor/flutter_new_pipe_extractor.dart';
import 'package:sonolyth/services/spotiflac/zarz_headless_verify.dart';
import 'package:sonolyth/hooks/configurators/use_zarz_keep_alive.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

Future<void> main(List<String> rawArgs) async {
  final arguments = await startCLI(rawArgs);
  AppLogger.initialize(arguments["verbose"]);

  AppLogger.runZoned(() async {
    WidgetsFlutterBinding.ensureInitialized();

    HttpOverrides.global = BadCertificateAllowlistOverrides();

    tz.initializeTimeZones();

    MediaKit.ensureInitialized();

    // High refresh rate + portrait lock moved to useAndroidDisplaySetup:
    // both need an attached activity, and when AudioService boots this
    // engine headlessly (media-button press after a process kill) they threw
    // noActivity here — aborting main() before runApp and leaving a cached
    // engine with no UI, which every later launch attached to as a
    // permanently black screen.
    if (kIsAndroid) {
      await NewPipeExtractor.init();
    }

    MetadataGod.initialize();

    await KVStoreService.initialize();

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

    // One-time: drop matches picked before v5.2.63's matcher fixes. The old
    // matcher compared artists by substring containment ("George" matched
    // "George Hampton") and deleted all non-ASCII characters, so wrong-artist
    // and wrong-song matches are sitting in the cache and would keep playing
    // wrong forever. Re-resolving re-matches with the exact-token matcher.
    if (KVStoreService.sharedPreferences.getBool('sourceMatchExactArtistV1') !=
        true) {
      await database.delete(database.sourceMatchTable).go();
      await KVStoreService.sharedPreferences
          .setBool('sourceMatchExactArtistV1', true);
    }

    // One-time: v5.2.64's over-strict matcher (no bracketed alt-script artist
    // handling, Qobuz text search skipped after junk ISRC results) rejected
    // lossless matches and permanently pinned YouTube fallbacks — often the
    // wrong song. Drop ONLY the YouTube-pinned rows; lossless matches are
    // ISRC-verified/scored and stay, so this doesn't re-trigger a full
    // re-resolve storm.
    if (KVStoreService.sharedPreferences.getBool('sourceMatchYtRepinV1') !=
        true) {
      final rows = await database.select(database.sourceMatchTable).get();
      final youtubePinned = rows
          .where((row) =>
              !row.sourceInfo.contains(QobuzAudioSource.externalUriPrefix) &&
              !row.sourceInfo.contains(TidalAudioSource.externalUriPrefix))
          .map((row) => row.id)
          .toList();
      if (youtubePinned.isNotEmpty) {
        await (database.delete(database.sourceMatchTable)
              ..where((s) => s.id.isIn(youtubePinned)))
            .go();
      }
      await KVStoreService.sharedPreferences
          .setBool('sourceMatchYtRepinV1', true);
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

/// Zenith corner softening.
///
/// **Proxima's corners are bimodal, and it is the artwork that is square, not
/// the containers.** Reading every `corners_*` out of `@style/proxima`:
///
/// | group | value |
/// | --- | --- |
/// | all `corners_aa_*`, miniplayer art, `corners_equ_frs` | **0dp** |
/// | `corners_small` / `corners_navbar` | 1dp / 5dp |
/// | `corners_medium`, `corners_medium_plus`, `corners_popup` | **20dp** |
/// | `corners_mini` / `corners_large` | 25dp / 30dp |
/// | `corners_searchbar` | 60dp |
///
/// So panels, popups and menus are *rounder* than Material's defaults, not
/// tighter. shadcn derives its ramp from this one scalar as
/// `radiusXs..radiusXxl = radius * 4..24`, so 1.0 puts `radiusXl` exactly on
/// `corners_popup`/`corners_medium` (20dp) and `radiusLg` at 16.
///
/// This was 0.4 on the theory that "Proxima keeps corners tight". That reads
/// the artwork tokens and applies them to containers; the widgets that really
/// are square say so themselves with an explicit 0 (see `ZenithCardMetrics`,
/// `ZenithTrackRowMetrics`).
const _kZenithRadius = 1.0;

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
    // Load the measured edge-silence registry up front, for the same reason:
    // media construction reads it synchronously.
    ref.listen(trackTrimProvider, (_, __) {});
    ref.listen(bonsoirProvider, (_, __) {});
    ref.listen(connectClientsProvider, (_, __) {});
    ref.listen(serverProvider, (_, __) {});
    ref.listen(metadataPluginsProvider, (_, __) {});
    ref.listen(metadataPluginProvider, (_, __) {});
    ref.listen(audioSourcePluginProvider, (_, __) {});
    ref.listen(metadataPluginUpdateCheckerProvider, (_, __) {});
    ref.listen(audioSourcePluginUpdateCheckerProvider, (_, __) {});

    useAndroidDisplaySetup();
    useDisableBatteryOptimizations();

    // `history_table` is the one table nothing ever removes from: a row per
    // played track plus one per collection opened, each carrying the item's
    // full JSON (CONTEXT item 40). Bound it here rather than on the write
    // path — it is append-only housekeeping, and no frame is waiting on it.
    // Ten seconds in, well clear of the launch the user is watching.
    useEffect(() {
      Future(() async {
        await Future.delayed(const Duration(seconds: 10));
        final removed = await pruneHistory(ref.read(databaseProvider));
        if (removed > 0) {
          AppLogger.diag("[history] pruned $removed rows past retention");
        }
      }).catchError((Object e) {
        AppLogger.reportError(e, StackTrace.current);
      });
      return null;
    }, []);

    // Warm the lossless sessions at launch. This is a read-only check: a
    // `GET /bootstrap` mints a challenge server-side, the gateway has never
    // answered one with a session (CONTEXT §17a), and an install that keeps
    // minting challenges it never opens gets every signed call answered
    // `428 VERIFY_REQUIRED` for a while (§23) — so nothing here may bootstrap
    // except the headless attempt, which opens the challenge it minted.
    //
    // When there is no session, solve the Turnstile in a headless WebView
    // rather than leaving playback dead until the user happens to open
    // Settings → Playback. Sequentially, not `Future.wait`: two challenge
    // pages racing each other is two WebViews competing for the same
    // renderer, and neither is urgent.
    // Sessions that exist are refreshed on launch / resume / a timer so
    // they never lapse while the app is in use (they live ten hours).
    useZarzSessionKeepAlive(ref);
    useEffect(() {
      Future(() async {
        // Let the first frames land before spinning up a hidden WebView:
        // the challenge page competes with the UI for the main thread, and
        // a launch that stutters through two 25-second solves read as "the
        // app is slow". 15 s is generous for a Turnstile that is going to
        // pass on its own (it does so in a few seconds); one that wants a
        // click will not pass at 25 s either.
        await Future.delayed(const Duration(seconds: 4));
        var granted = false;
        for (final session in [ZarzSession.qobuz, ZarzSession.tidal]) {
          if (await session.isAuthenticated()) continue;
          granted = await tryZarzHeadlessVerify(
                session,
                timeout: const Duration(seconds: 15),
              ) ||
              granted;
        }
        // A headless solve that lands after the first track already failed to
        // resolve has to re-open it, or the session is verified and nothing
        // plays until the next launch.
        if (granted && context.mounted) {
          await reloadPlaybackAfterVerification(ref);
        }
      }).catchError((Object e) {
        AppLogger.reportError(e, StackTrace.current);
      });
      return null;
    }, []);

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

        return child;
      },
      scaling: const AdaptiveScaling(1),
      // Zenith geometry: flat and opaque. Proxima defines
      // `m3_sys_elevation_level0 = 0dp` and paints depth with alpha alone, so
      // surfaces never blur or float — only the radius softens them.
      theme: ThemeData(
        radius: _kZenithRadius,
        iconTheme: const IconThemeProperties(),
        colorScheme: resolveColorScheme(ThemeMode.light),
        surfaceOpacity: 1,
        surfaceBlur: 0,
      ),
      darkTheme: ThemeData(
        radius: _kZenithRadius,
        iconTheme: const IconThemeProperties(),
        colorScheme: resolveColorScheme(ThemeMode.dark),
        surfaceOpacity: 1,
        surfaceBlur: 0,
      ),
      // The Material layer must not drift from the shadcn one, or Material
      // widgets (dialogs, ListTiles, the bottom sheet) reintroduce the tinted
      // M3 surfaces Zenith exists to avoid. Derive it from the same scheme
      // instead of seeding a hue off the accent.
      materialTheme: () {
        final scheme = resolveColorScheme(effectiveThemeMode);
        return material.ThemeData(
          brightness: materialBrightness,
          scaffoldBackgroundColor: scheme.background,
          canvasColor: scheme.background,
          colorScheme: material.ColorScheme(
            brightness: materialBrightness,
            primary: scheme.primary,
            onPrimary: scheme.primaryForeground,
            secondary: scheme.secondary,
            onSecondary: scheme.secondaryForeground,
            error: scheme.destructive,
            onError: scheme.destructiveForeground,
            surface: scheme.card,
            onSurface: scheme.cardForeground,
            surfaceContainerHighest: scheme.muted,
            onSurfaceVariant: scheme.mutedForeground,
            outline: scheme.border,
            outlineVariant: scheme.border,
          ),
          dividerColor: scheme.border,
          // Zenith is flat: no tint, no shadow, no elevation overlays.
          splashFactory: material.NoSplash.splashFactory,
          appBarTheme: const material.AppBarTheme(
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            shadowColor: Colors.transparent,
            elevation: 0,
          ),
          dialogTheme: material.DialogThemeData(
            backgroundColor: scheme.popover,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          bottomSheetTheme: material.BottomSheetThemeData(
            backgroundColor: scheme.popover,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            modalElevation: 0,
          ),
          cardTheme: material.CardThemeData(
            color: scheme.card,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
        );
      }(),
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
