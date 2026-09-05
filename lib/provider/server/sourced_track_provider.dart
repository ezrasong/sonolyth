import 'dart:async';

import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/metadata_plugin/audio_source/quality_presets.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/server/track_format_registry.dart';
import 'package:sonolyth/services/sourced_track/exceptions.dart';
import 'package:sonolyth/services/sourced_track/sourced_track.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

class SourcedTrackNotifier
    extends FamilyAsyncNotifier<SourcedTrack, SonolythFullTrackObject> {
  @override
  FutureOr<SourcedTrack> build(query) {
    ref.watch(audioSourcePluginProvider);
    ref.watch(audioSourcePresetsProvider);

    // Every resolution this entry ever holds — the first fetch, a refreshed
    // URL, a sibling swap — is published to the format registry, so a list
    // row can show "flac | 24 bit" for any track resolved this session
    // without the row itself ever triggering a resolve.
    listenSelf((_, next) {
      final stream = next.valueOrNull?.selectedStream;
      if (stream == null) return;
      ref
          .read(trackFormatRegistryProvider.notifier)
          .record(query.id, TrackFormat.fromStream(stream));
    });

    return SourcedTrack.fetchFromTrack(query: query, ref: ref);
  }

  Future<SourcedTrack> refreshStreamingUrl() async {
    return await update((prev) async {
      return await prev.refreshStream();
    });
  }

  Future<SourcedTrack> copyWithSibling() async {
    return await update((prev) async {
      return prev.copyWithSibling();
    });
  }

  Future<SourcedTrack> swapWithSibling(
    SonolythAudioSourceMatchObject sibling,
  ) async {
    return await update((prev) async {
      return await prev.swapWithSibling(sibling) ?? prev;
    });
  }

  Future<SourcedTrack> swapWithNextSibling() async {
    return await update((prev) async {
      // siblings can be exhausted (no fallback sources left); throw a clear
      // error instead of letting `.first` raise a bare StateError and the
      // null-returning swap blow up the cast.
      final next = prev.siblings.firstOrNull;
      if (next == null) {
        throw TrackNotFoundError(prev.query);
      }
      return await prev.swapWithSibling(next) ?? prev;
    });
  }
}

final sourcedTrackProvider = AsyncNotifierProviderFamily<SourcedTrackNotifier,
    SourcedTrack, SonolythFullTrackObject>(
  () => SourcedTrackNotifier(),
);

/// Reads [sourcedTrackProvider] for [track], retrying once when the cached
/// state is an error. A resolve that failed transiently (screen-off radio
/// sleep, gateway hiccup) otherwise sticks as an error forever — the family
/// provider never rebuilds on its own, so the track could never play until
/// something else invalidated it.
Future<SourcedTrack> readSourcedTrack(
  Ref ref,
  SonolythFullTrackObject track,
) {
  final provider = sourcedTrackProvider(track);
  if (ref.read(provider).hasError) {
    ref.invalidate(provider);
  }
  return ref.read(provider.future);
}

/// Re-resolves every track and re-opens the current one, after lossless access
/// has just been granted.
///
/// Without this, verifying fixes nothing you can *hear*. The track that was
/// loaded resolved before the session existed, so its `sourcedTrackProvider`
/// entry holds a `ZarzVerificationRequiredException`; the family never
/// rebuilds on its own, and [readSourcedTrack]'s retry only helps the next
/// track someone asks for. The observed behaviour was: verify, watch the badge
/// flip to "Verified", press play — and the track still sits at 00:00 until
/// the app is restarted or you skip away and back.
Future<void> reloadPlaybackAfterVerification(WidgetRef ref) async {
  ref.invalidate(sourcedTrackProvider);

  final player = ref.read(audioPlayerProvider.notifier);

  // A queue held out of mpv (§43) has no media to re-open and no index to jump
  // to — mpv's playlist is empty. Handing it over *is* the reload, and doing
  // it first means the jump below has something to jump to.
  if (await player.resumeDeferredQueue()) return;

  final active = ref.read(audioPlayerProvider).activeTrack;
  if (active == null) return;

  // Jumping to the index it is already on is what re-opens the media, so the
  // now-resolvable URL actually reaches the engine.
  await player.jumpToTrack(active);
}

/// Whether the **active** track is blocked because lossless access needs a
/// Turnstile check.
///
/// This exists because the verify prompt is an *event* and the player needs a
/// *state* (CONTEXT item 53). `use_zarz_verify_prompt.dart` raises a toast the
/// moment a resolve fails: it lasts twelve seconds, it is rate-limited to one
/// every two minutes, and it appears wherever the user happened to be standing
/// — which in practice is a list page, because that is where playback starts.
/// Open the player a minute later and there is nothing to see: 00:00 / 00:00, a
/// dead transport and a codec chip confidently naming a stream that was never
/// fetched. The banner was never "list-only by design"; it is simply gone by
/// the time the one screen that looks broken gets opened.
///
/// Watching [sourcedTrackProvider] here costs nothing extra: the verify prompt
/// already holds a subscription to the same family entry for the same track.
final activeTrackVerificationBlockedProvider = Provider<bool>((ref) {
  final track = ref.watch(audioPlayerProvider.select((s) => s.activeTrack));
  if (track is! SonolythFullTrackObject) return false;

  final resolution = ref.watch(sourcedTrackProvider(track));
  return resolution.hasError &&
      resolution.error is ZarzVerificationRequiredException;
});
