import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show ListTile;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/ui/zenith_filter_chip.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/adaptive/adaptive_select_tile.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/models/playback/crossfade.dart';
import 'package:sonolyth/modules/settings/playback/edit_connect_port_dialog.dart';
import 'package:sonolyth/modules/settings/playback/zarz_verify_dialog.dart';
import 'package:sonolyth/modules/settings/section_card_with_heading.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/history/history.dart';
import 'package:sonolyth/provider/local_tracks/local_tracks_provider.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';

import 'package:sonolyth/utils/platform.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';

class SettingsPlaybackSection extends HookConsumerWidget {
  const SettingsPlaybackSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
    final theme = Theme.of(context);

    return SectionCardWithHeading(
      heading: context.l10n.playback,
      children: [
        // Playback is lossless-only: every track resolves to FLAC via Qobuz,
        // then Tidal. There is no lossy fallback, so the old YouTube engine
        // picker and the streaming format/quality presets (which only ever
        // governed the YouTube fallback) have been removed.
        ListTile(
          leading: const Icon(SonolythIcons.audioQuality),
          title: Text(context.l10n.streaming_music_format),
          subtitle: const Text(
            "Lossless FLAC via Qobuz, then Tidal. Tracks neither catalog "
            "carries won't play.",
          ),
          trailing: const ZenithValueChip(child: Text("FLAC · Lossless")),
        ),
        const _ZarzAccessTile(
          session: _ZarzSourceKind.qobuz,
        ),
        const _ZarzAccessTile(
          session: _ZarzSourceKind.tidal,
        ),
        ListTile(
          title: Text(context.l10n.cache_music),
          subtitle: kIsMobile
              ? null
              : Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: "${context.l10n.open} "),
                      TextSpan(
                        text: context.l10n.cache_folder.toLowerCase(),
                        recognizer: TapGestureRecognizer()
                          ..onTap = preferencesNotifier.openCacheFolder,
                        style: theme.typography.normal.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      )
                    ],
                  ),
                ),
          leading: const Icon(SonolythIcons.cache),
          trailing: Switch(
            value: preferences.cacheMusic,
            onChanged: preferencesNotifier.setCacheMusic,
          ),
        ),
        const _MusicCacheSizeTile(),
        const _PlayHistoryTile(),
        ListTile(
          leading: const Icon(SonolythIcons.playlistRemove),
          title: Text(context.l10n.blacklist),
          subtitle: Text(context.l10n.blacklist_description),
          onTap: () {
            context.navigateTo(const BlackListRoute());
          },
          trailing: const Icon(SonolythIcons.angleRight),
        ),
        ListTile(
          leading: const Icon(SonolythIcons.normalize),
          title: Text(context.l10n.normalize_audio),
          trailing: Switch(
            value: preferences.normalizeAudio,
            onChanged: preferencesNotifier.setNormalizeAudio,
          ),
        ),
        const _CrossfadeTile(),
        ListTile(
            leading: const Icon(SonolythIcons.repeat),
            title: Text(context.l10n.endless_playback),
            trailing: Switch(
              value: preferences.endlessPlayback,
              onChanged: preferencesNotifier.setEndlessPlayback,
            )),
        ListTile(
          title: Text(context.l10n.enable_connect),
          subtitle: Text(context.l10n.enable_connect_description),
          leading: const Icon(SonolythIcons.connect),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              ZenithTooltip(
                message: context.l10n.edit_port,
                // A bare glyph — `ItemHeader*Button` is transparent.
                child: IconButton.ghost(
                  shape: ButtonShape.circle,
                  icon: const Icon(SonolythIcons.edit),
                  size: ButtonSize.small,
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withValues(alpha: 0.5),
                      builder: (context) =>
                          const SettingsPlaybackEditConnectPortDialog(),
                    );
                  },
                ),
              ),
              Switch(
                value: preferences.enableConnect,
                onChanged: preferencesNotifier.setEnableConnect,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// How much disk the cached tracks are using, and the one tap that frees it.
///
/// The cache is a real folder that grows without a ceiling — 176 MB for eight
/// tracks on the emulator — and until now the only in-app route to it was the
/// tooltip-only trash glyph on the Local library's "Cache folder" row, which
/// nobody looking at the "Cache music" switch would ever find. The size sits
/// next to the switch that creates it.
class _MusicCacheSizeTile extends HookConsumerWidget {
  const _MusicCacheSizeTile();

  /// Decimal units, matching what Android's own storage screens report. The
  /// existing `size_in_gb` string is GB-only, which renders a full cache as
  /// "0.18 GB" — useless at the size this folder actually reaches.
  static String formatBytes(int bytes) {
    if (bytes >= 1000000000) {
      return "${(bytes / 1000000000).toStringAsFixed(2)} GB";
    }
    if (bytes >= 1000000) return "${(bytes / 1000000).round()} MB";
    if (bytes >= 1000) return "${(bytes / 1000).round()} KB";
    return "$bytes B";
  }

  static Future<int> _cacheBytes() async {
    final dir = Directory(await UserPreferencesNotifier.getMusicCacheDir());
    if (!await dir.exists()) return 0;

    final entries = await dir.list(recursive: true).toList();
    final lengths = await Future.wait(
      entries.whereType<File>().map((file) => file.length()),
    );
    return lengths.fold<int>(0, (sum, length) => sum + length);
  }

  @override
  Widget build(BuildContext context, ref) {
    // Bumped after a clear so the size is re-read rather than left stale.
    final revision = useState(0);
    final size = useFuture(
      useMemoized(_cacheBytes, [revision.value]),
      preserveState: false,
    );

    final bytes = size.data;
    final isEmpty = bytes == null || bytes == 0;

    Future<void> onClear() async {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.clear_cache_confirmation),
          actions: [
            Button.outline(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.decline),
            ),
            Button.destructive(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.accept),
            ),
          ],
        ),
      );
      if (accepted != true) return;

      final dir = Directory(await UserPreferencesNotifier.getMusicCacheDir());
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      revision.value++;
      // The cache folder is one of the Local library's folders.
      ref.invalidate(localTracksProvider);
    }

    return ListTile(
      leading: const Icon(SonolythIcons.delete),
      title: Text(context.l10n.clear_cache),
      enabled: !isEmpty,
      onTap: isEmpty ? null : onClear,
      trailing: ZenithValueChip(
        // A dash until the walk finishes, so an unknown size never reads as
        // an empty cache.
        child: Text(bytes == null ? "—" : formatBytes(bytes)),
      ),
    );
  }
}

/// Crossfade length + curve. The slider commits on release (not per-pixel) so
/// dragging it doesn't write a row — and re-arm the engine — 200 times.
class _CrossfadeTile extends HookConsumerWidget {
  const _CrossfadeTile();

  @override
  Widget build(BuildContext context, ref) {
    final seconds = ref.watch(
      userPreferencesProvider.select((s) => s.crossfadeDuration),
    );
    final curve = ref.watch(
      userPreferencesProvider.select((s) => s.crossfadeCurve),
    );
    final notifier = ref.read(userPreferencesProvider.notifier);
    final theme = Theme.of(context);

    // Mirrors the stored value while dragging so the label tracks the thumb.
    final draft = useState<double?>(null);
    final shown = draft.value?.round() ?? seconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(SonolythIcons.shuffle),
          title: Text(context.l10n.crossfade),
          subtitle: Text(
            shown == 0
                ? context.l10n.crossfade_off_description
                : context.l10n.crossfade_seconds(shown),
          ),
          trailing: ZenithValueChip(
            child: Text(shown == 0 ? context.l10n.off : "${shown}s"),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Slider(
            min: 0,
            max: maxCrossfadeSeconds.toDouble(),
            divisions: maxCrossfadeSeconds,
            value: SliderValue.single(shown.toDouble()),
            onChanged: (value) => draft.value = value.value,
            onChangeEnd: (value) {
              draft.value = null;
              notifier.setCrossfadeDuration(value.value.round());
            },
          ),
        ),
        if (shown > 0)
          AdaptiveSelectTile<CrossfadeCurve>(
            secondary: const Icon(SonolythIcons.normalize),
            title: Text(context.l10n.crossfade_curve),
            subtitle: Text(
              context.l10n.crossfade_curve_description,
              style: theme.typography.small,
            ),
            value: curve,
            options: [
              SelectItemButton(
                value: CrossfadeCurve.equalPower,
                child: Text(context.l10n.crossfade_curve_equal_power),
              ),
              SelectItemButton(
                value: CrossfadeCurve.linear,
                child: Text(context.l10n.crossfade_curve_linear),
              ),
            ],
            onChanged: (value) {
              if (value != null) notifier.setCrossfadeCurve(value);
            },
          ),
      ],
    );
  }
}

enum _ZarzSourceKind {
  qobuz("Qobuz"),
  tidal("Tidal");

  const _ZarzSourceKind(this.label);
  final String label;

  ZarzSession get session =>
      this == _ZarzSourceKind.qobuz ? ZarzSession.qobuz : ZarzSession.tidal;
}

/// Shows whether lossless access for one source is verified, and offers the
/// one-time human check when it isn't. Verification is what gates FLAC now
/// that YouTube is gone, so it needs to be visible and re-runnable rather than
/// hidden behind a toggle.
class _ZarzAccessTile extends HookConsumerWidget {
  const _ZarzAccessTile({required this.session});

  final _ZarzSourceKind session;

  @override
  Widget build(BuildContext context, ref) {
    final checking = useState(true);
    final verified = useState(false);
    final busy = useState(false);

    Future<void> refresh() async {
      // Read-only. A status tile must never mint a gateway challenge: the
      // silent bootstrap this used to run never yields a session (CONTEXT
      // §17a), and every abandoned challenge counts against the install
      // (§23). "Not verified" + the Verify button is the honest state.
      // A session the gateway is refusing with 428 is not access. Saying
      // "Verified" there hides the only button that can fix it.
      final ok = await session.session.isAuthenticated() &&
          !session.session.isFlaggedDespiteSession;
      // The tile can be gone by the time the check returns (Settings
      // scrolled past it, the page left); a disposed hook notifier throws.
      if (!context.mounted) return;
      verified.value = ok;
      checking.value = false;
    }

    useEffect(() {
      refresh();
      return null;
    }, [session]);

    return ListTile(
      leading: const Icon(SonolythIcons.audioQuality),
      title: Text("${session.label} lossless access"),
      subtitle: Text(
        checking.value
            ? "Checking…"
            : verified.value
                ? "Verified — lossless streaming and downloads are active."
                : "Not verified. ${session.label} needs a one-time human "
                    "check before it can serve lossless audio.",
      ),
      trailing: checking.value
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(),
            )
          : verified.value
              ? const ZenithValueChip(
                  icon: SonolythIcons.done,
                  child: Text("Verified"),
                )
              // `DialogPositiveButtonStyle` — see [zenithPositiveButton].
              : Button(
                  style: zenithPositiveButton(Theme.of(context).colorScheme),
                  onPressed: busy.value
                      ? null
                      : () async {
                          busy.value = true;
                          try {
                            final ok = await showZarzVerifyDialog(
                              context,
                              session.session,
                              sourceLabel: session.label,
                            );
                            if (!context.mounted) return;
                            verified.value = ok;
                            // Verifying has to unblock the track that sent the
                            // user here, not just the next one.
                            if (ok) await reloadPlaybackAfterVerification(ref);
                          } finally {
                            if (context.mounted) busy.value = false;
                          }
                        },
                  child: const Text("Verify"),
                ),
    );
  }
}


/// "Clear play history" — the one control over `history_table` (CONTEXT
/// item 40).
///
/// Retention runs on its own at launch (`pruneHistory`), and this is the other
/// half of that decision: an app that keeps a log of everything you listened to
/// has to let you throw it away, and `PlaybackHistoryActions.clear()` existed
/// with no call site anywhere in the UI. The count on the chip is what makes
/// the row honest — it says how much is being kept, so "clear" is a number and
/// not a promise.
///
/// Shaped exactly like [_MusicCacheSizeTile] above it: a dash while the count
/// is unknown (so an unread table never reads as an empty one), disabled at
/// zero, a destructive confirm, and an in-place re-read afterwards.
class _PlayHistoryTile extends HookConsumerWidget {
  const _PlayHistoryTile();

  @override
  Widget build(BuildContext context, ref) {
    final history = ref.watch(playbackHistoryActionsProvider);
    // Bumped after a clear so the count is re-read rather than left stale.
    final revision = useState(0);
    final count = useFuture(
      useMemoized(history.count, [revision.value]),
      preserveState: false,
    );

    final rows = count.data;
    final isEmpty = rows == null || rows == 0;

    Future<void> onClear() async {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.clear_play_history_confirmation),
          actions: [
            Button.outline(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.decline),
            ),
            Button.destructive(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.accept),
            ),
          ],
        ),
      );
      if (accepted != true) return;

      await history.clear();
      revision.value++;
    }

    return ListTile(
      leading: const Icon(SonolythIcons.delete),
      title: Text(context.l10n.clear_play_history),
      subtitle: Text(context.l10n.clear_play_history_description),
      enabled: !isEmpty,
      onTap: isEmpty ? null : onClear,
      trailing: ZenithValueChip(
        child: Text(
          rows == null ? "—" : context.l10n.count_plays_kept(rows),
        ),
      ),
    );
  }
}
