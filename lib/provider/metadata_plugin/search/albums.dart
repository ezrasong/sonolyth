import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/family_paginated.dart';

class MetadataPluginSearchAlbumsNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SonolythSimpleAlbumObject,
        String> {
  MetadataPluginSearchAlbumsNotifier() : super();

  @override
  fetch(offset, limit) async {
    if (arg.isEmpty) {
      return SonolythPaginationResponseObject<SonolythSimpleAlbumObject>(
        limit: limit,
        nextOffset: null,
        total: 0,
        items: [],
        hasMore: false,
      );
    }

    final res = await (await metadataPlugin).search.albums(
          arg,
          offset: offset,
          limit: limit,
        );

    return res;
  }

  @override
  build(arg) async {
    ref.cacheFor();

    ref.watch(metadataPluginProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginSearchAlbumsProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginSearchAlbumsNotifier,
        SonolythPaginationResponseObject<SonolythSimpleAlbumObject>, String>(
  () => MetadataPluginSearchAlbumsNotifier(),
);
