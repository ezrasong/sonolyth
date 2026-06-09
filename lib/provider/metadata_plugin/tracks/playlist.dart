import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/metadata_plugin/utils/family_paginated.dart';
import 'package:spotube/provider/metadata_plugin/utils/common.dart';
import 'package:spotube/services/cache/playlist_tracks_cache.dart';
import 'package:spotube/services/logger/logger.dart';

class MetadataPluginPlaylistTracksNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SpotubeFullTrackObject,
        String> {
  MetadataPluginPlaylistTracksNotifier() : super();

  /// The gql pathfinder API serves 100 tracks per request just fine (the
  /// fetchAll path always used it); 20-track pages made long playlists crawl.
  static const _pageSize = 100;

  @override
  fetch(offset, limit) async {
    final tracks = await (await metadataPlugin).playlist.tracks(
          arg,
          offset: offset,
          limit: limit,
        );

    return tracks;
  }

  /// In-flight full load, shared between the background loader, the play
  /// button's fetchAll and scroll pagination so pages never double-fetch.
  Future<List<SpotubeFullTrackObject>>? _fetchAllFuture;

  @override
  Future<List<SpotubeFullTrackObject>> fetchAll() {
    return _fetchAllFuture ??=
        super.fetchAll().whenComplete(() => _fetchAllFuture = null);
  }

  @override
  Future<void> fetchMore() async {
    if (_fetchAllFuture != null) return;
    return super.fetchMore();
  }

  /// Loads every remaining page (UI updates as chunks arrive) and persists
  /// the complete listing to the disk cache.
  Future<void> _loadRestAndPersist() async {
    try {
      await fetchAll();
      final data = state.valueOrNull;
      if (data != null && !data.hasMore) {
        await PlaylistTracksCache.write(arg, data);
      }
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  @override
  build(arg) async {
    ref.cacheFor();

    ref.watch(metadataPluginProvider);

    final cached = await PlaylistTracksCache.read(arg);
    if (cached != null) {
      // Serve the cached listing instantly; verify against the server in the
      // background and only swap the state when something actually changed.
      Future(() async {
        try {
          final fresh = await fetch(0, _pageSize);
          final unchanged = !cached.hasMore &&
              fresh.total == cached.total &&
              const ListEquality().equals(
                fresh.items.map((e) => e.id).toList(),
                cached.items
                    .take(fresh.items.length)
                    .map((e) => e.id)
                    .toList(),
              );
          if (unchanged) return;
          state = AsyncData(fresh);
          await _loadRestAndPersist();
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      });
      return cached;
    }

    final first = await fetch(0, _pageSize);
    Future(() => _loadRestAndPersist());
    return first;
  }
}

final metadataPluginPlaylistTracksProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginPlaylistTracksNotifier,
        SpotubePaginationResponseObject<SpotubeFullTrackObject>, String>(
  () => MetadataPluginPlaylistTracksNotifier(),
);
