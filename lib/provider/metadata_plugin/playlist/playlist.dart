import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/library/playlists.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/core/user.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:sonolyth/services/cache/metadata_object_cache.dart';
import 'package:sonolyth/services/metadata/errors/exceptions.dart';
import 'package:sonolyth/services/metadata/metadata.dart';

class MetadataPluginPlaylistNotifier
    extends AutoDisposeFamilyAsyncNotifier<SonolythFullPlaylistObject, String> {
  Future<MetadataPlugin> get metadataPlugin async {
    final metadataPlugin = await ref.read(metadataPluginProvider.future);

    if (metadataPlugin == null) {
      throw MetadataPluginException.noDefaultMetadataPlugin();
    }

    return metadataPlugin;
  }

  @override
  build(playlistId) async {
    ref.cacheFor();

    // Short disk cache: playlist headers (name/image/owner) change rarely, and
    // the tracks listing has its own change detection. Stale entries still
    // serve as a fallback when the provider rate-limits.
    return MetadataObjectCache.fetchWithCache(
      namespace: 'playlist',
      id: playlistId,
      maxAge: const Duration(hours: 6),
      fetch: () async => (await metadataPlugin).playlist.getPlaylist(playlistId),
      fromJson: SonolythFullPlaylistObject.fromJson,
      toJson: (playlist) => playlist.toJson(),
    );
  }

  Future<void> create({
    required String name,
    String? description,
    bool? public,
    bool? collaborative,
    void Function(dynamic error)? onError,
  }) async {
    final userId = await ref
        .read(metadataPluginUserProvider.selectAsync((data) => data?.id));
    if (userId == null) {
      throw Exception('User ID is not available. Please log in first.');
    }
    state = const AsyncValue.loading();
    try {
      final playlist = await (await metadataPlugin).playlist.create(
            userId,
            name: name,
            description: description,
            public: public,
            collaborative: collaborative,
          );
      if (playlist != null) {
        state = AsyncValue.data(playlist);
      }
      ref.invalidate(metadataPluginSavedPlaylistsProvider);
    } catch (e) {
      onError?.call(e);
      rethrow;
    }
  }

  Future<void> modify({
    String? name,
    String? description,
    bool? public,
    bool? collaborative,
    void Function(dynamic error)? onError,
  }) async {
    try {
      if (name == null &&
          description == null &&
          public == null &&
          collaborative == null) {
        throw Exception('No modifications provided.');
      }
      await (await metadataPlugin).playlist.update(
            arg,
            name: name,
            description: description,
            public: public,
            collaborative: collaborative,
          );
      await MetadataObjectCache.evict('playlist', arg);
      ref.invalidateSelf();
    } on Exception catch (e) {
      onError?.call(e);
      rethrow;
    }
  }

  Future<void> addTracks(List<String> trackIds,
      [void Function(dynamic error)? onError]) async {
    if (state.value == null) return;

    try {
      await ref
          .read(metadataPluginSavedPlaylistsProvider.notifier)
          .addTracks(arg, trackIds);
    } catch (e) {
      onError?.call(e);
      rethrow;
    }
  }

  Future<void> removeTracks(List<String> trackIds,
      [void Function(dynamic error)? onError]) async {
    try {
      if (state.value == null) return;

      await ref
          .read(metadataPluginSavedPlaylistsProvider.notifier)
          .removeTracks(arg, trackIds);
    } catch (e) {
      onError?.call(e);
      rethrow;
    }
  }

  Future<void> delete() async {
    if (state.value == null) return;
    final userId = await ref
        .read(metadataPluginUserProvider.selectAsync((data) => data?.id));
    if (userId == null || userId != state.value!.owner.id) {
      throw Exception('You can only delete your own playlists.');
    }

    await ref.read(metadataPluginSavedPlaylistsProvider.notifier).delete(arg);
  }
}

final metadataPluginPlaylistProvider = AutoDisposeAsyncNotifierProviderFamily<
    MetadataPluginPlaylistNotifier, SonolythFullPlaylistObject, String>(
  () => MetadataPluginPlaylistNotifier(),
);
