import 'dart:async';

import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/audio_source/quality_presets.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/services/sourced_track/exceptions.dart';
import 'package:sonolyth/services/sourced_track/sourced_track.dart';

class SourcedTrackNotifier
    extends FamilyAsyncNotifier<SourcedTrack, SonolythFullTrackObject> {
  @override
  FutureOr<SourcedTrack> build(query) {
    ref.watch(audioSourcePluginProvider);
    ref.watch(audioSourcePresetsProvider);

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
