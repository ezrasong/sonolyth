import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/family_paginated.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:sonolyth/services/cache/playlist_tracks_cache.dart';
import 'package:sonolyth/services/logger/logger.dart';

class MetadataPluginArtistTopTracksNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SonolythFullTrackObject,
        String> {
  MetadataPluginArtistTopTracksNotifier() : super();

  static const _cache = TrackListingCache('artist-top-tracks-cache');

  @override
  fetch(offset, limit) async {
    final tracks = await (await metadataPlugin).artist.topTracks(
          arg,
          offset: offset,
          limit: limit,
        );

    return tracks;
  }

  @override
  build(arg) async {
    ref.cacheFor();

    ref.watch(metadataPluginProvider);

    // Top tracks shift slowly; a day of disk cache makes artist pages load
    // instantly without burning the provider's rate limit on every visit.
    final cached = await _cache.read(arg, maxAge: const Duration(days: 1));
    if (cached != null) return cached;

    final first = await fetch(0, 20);
    Future(() async {
      try {
        if (!first.hasMore) await _cache.write(arg, first);
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
    return first;
  }
}

final metadataPluginArtistTopTracksProvider =
    AutoDisposeAsyncNotifierProviderFamily<
        MetadataPluginArtistTopTracksNotifier,
        SonolythPaginationResponseObject<SonolythFullTrackObject>,
        String>(
  () => MetadataPluginArtistTopTracksNotifier(),
);
