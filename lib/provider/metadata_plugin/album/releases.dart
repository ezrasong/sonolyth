import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/paginated.dart';

class MetadataPluginAlbumReleasesNotifier
    extends PaginatedAsyncNotifier<SonolythSimpleAlbumObject> {
  @override
  Future<SonolythPaginationResponseObject<SonolythSimpleAlbumObject>> fetch(
    int offset,
    int limit,
  ) async {
    return await (await metadataPlugin)
        .album
        .releases(limit: limit, offset: offset);
  }

  @override
  build() async {
    // Gate on auth: firing this before the plugin finishes restoring its
    // stored credentials hits Spotify with no bearer token and 403/400s on
    // launch. Awaiting the future means we only fetch once authenticated, and
    // the provider rebuilds (re-fetches) when the auth state stream flips true.
    final authenticated =
        await ref.watch(metadataPluginAuthenticatedProvider.future);
    if (!authenticated) {
      return SonolythPaginationResponseObject(
        limit: 20,
        nextOffset: null,
        total: 0,
        hasMore: false,
        items: const [],
      );
    }
    // fetchWithRetry (not fetch): the startup request burst can trip Spotify's
    // 429 limiter; back off and retry instead of surfacing a hard error.
    return await fetchWithRetry(0, 20);
  }
}

final metadataPluginAlbumReleasesProvider = AsyncNotifierProvider<
    MetadataPluginAlbumReleasesNotifier,
    SonolythPaginationResponseObject<SonolythSimpleAlbumObject>>(
  () => MetadataPluginAlbumReleasesNotifier(),
);
