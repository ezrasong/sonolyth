import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:sonolyth/services/cache/metadata_object_cache.dart';
import 'package:sonolyth/services/metadata/errors/exceptions.dart';

final metadataPluginArtistProvider =
    FutureProvider.autoDispose.family<SonolythFullArtistObject, String>(
  (ref, artistId) async {
    ref.cacheFor();

    final metadataPlugin = await ref.watch(metadataPluginProvider.future);

    if (metadataPlugin == null) {
      throw MetadataPluginException.noDefaultMetadataPlugin();
    }

    // Artist profiles change rarely (name/images/follower counts); a few days
    // of disk cache makes artist pages open instantly.
    return MetadataObjectCache.fetchWithCache(
      namespace: 'artist',
      id: artistId,
      maxAge: const Duration(days: 3),
      fetch: () => metadataPlugin.artist.getArtist(artistId),
      fromJson: SonolythFullArtistObject.fromJson,
      toJson: (artist) => artist.toJson(),
    );
  },
);
