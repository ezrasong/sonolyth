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
    ref.watch(metadataPluginAuthenticatedProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginAlbumReleasesProvider = AsyncNotifierProvider<
    MetadataPluginAlbumReleasesNotifier,
    SonolythPaginationResponseObject<SonolythSimpleAlbumObject>>(
  () => MetadataPluginAlbumReleasesNotifier(),
);
