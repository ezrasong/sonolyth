import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:sonolyth/services/cache/metadata_object_cache.dart';
import 'package:sonolyth/services/metadata/errors/exceptions.dart';

final metadataPluginAlbumProvider =
    FutureProvider.autoDispose.family<SonolythFullAlbumObject, String>(
  (ref, id) async {
    ref.cacheFor();

    final metadataPlugin = await ref.watch(metadataPluginProvider.future);

    if (metadataPlugin == null) {
      throw MetadataPluginException.noDefaultMetadataPlugin();
    }

    // Album metadata is effectively immutable; serving it from disk makes
    // revisits instant and avoids burning the provider's rate limit.
    return MetadataObjectCache.fetchWithCache(
      namespace: 'album',
      id: id,
      maxAge: const Duration(days: 7),
      fetch: () => metadataPlugin.album.getAlbum(id),
      fromJson: SonolythFullAlbumObject.fromJson,
      toJson: (album) => album.toJson(),
    );
  },
);
