import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/family_paginated.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:sonolyth/services/cache/playlist_tracks_cache.dart';
import 'package:sonolyth/services/logger/logger.dart';

class MetadataPluginAlbumTracksNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SonolythFullTrackObject,
        String> {
  MetadataPluginAlbumTracksNotifier() : super();

  static const _cache = TrackListingCache('album-tracks-cache');

  @override
  fetch(offset, limit) async {
    final tracks = await (await metadataPlugin).album.tracks(
          arg,
          offset: offset,
          limit: limit,
        );

    return tracks;
  }

  /// Loads every remaining page and persists complete listings so the next
  /// visit renders the whole album from disk.
  Future<void> _loadRestAndPersist() async {
    try {
      await fetchAll();
      final data = state.valueOrNull;
      if (data != null && !data.hasMore) {
        await _cache.write(arg, data);
      }
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  @override
  build(arg) async {
    ref.cacheFor();

    ref.watch(metadataPluginProvider);

    // Album listings are effectively immutable; serve complete cached
    // listings for a week before re-checking.
    final cached = await _cache.read(arg, maxAge: const Duration(days: 7));
    if (cached != null && !cached.hasMore) return cached;

    final first = await fetch(0, 20);
    Future(() => _loadRestAndPersist());
    return first;
  }
}

final metadataPluginAlbumTracksProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginAlbumTracksNotifier,
        SonolythPaginationResponseObject<SonolythFullTrackObject>, String>(
  () => MetadataPluginAlbumTracksNotifier(),
);
