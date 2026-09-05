import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/family_paginated.dart';

/// Whether `related` is worth calling at all, for as long as the current
/// metadata plugin lives.
///
/// Spotify's `related` endpoint fails outright for some accounts — this one
/// included (§33b) — and it takes about **35 seconds** to say so, which every
/// artist page then paid on open (§35). The flag is a mutable holder rather
/// than provider state on purpose: it is set from inside the notifier's
/// `build`, and Riverpod forbids writing a provider there.
///
/// It hangs off [metadataPluginProvider], so logging in again, switching
/// plugin or a plugin reload all reset it and the endpoint gets a fresh
/// chance. Nothing here disables the section permanently: if the endpoint
/// starts working, the next launch shows "Fans also like" again with no
/// further change.
class RelatedArtistsAvailability {
  bool unavailable = false;
}

final _relatedArtistsAvailabilityProvider =
    Provider<RelatedArtistsAvailability>((ref) {
  ref.watch(metadataPluginProvider);
  return RelatedArtistsAvailability();
});

class MetadataPluginArtistRelatedArtistsNotifier
    extends FamilyPaginatedAsyncNotifier<SonolythFullArtistObject, String> {
  /// Generous for a slow phone on a slow network, and far short of the ~35s
  /// the endpoint itself takes to fail. "Fans also like" is decoration: it is
  /// not worth a page-load's worth of waiting either way.
  static const _timeout = Duration(seconds: 10);

  static SonolythPaginationResponseObject<SonolythFullArtistObject> get _none =>
      SonolythPaginationResponseObject(
        limit: 20,
        nextOffset: null,
        total: 0,
        hasMore: false,
        items: const [],
      );

  @override
  Future<SonolythPaginationResponseObject<SonolythFullArtistObject>> fetch(
    int offset,
    int limit,
  ) async {
    return await (await metadataPlugin)
        .artist
        .related(
          arg,
          limit: limit,
          offset: offset,
        )
        .timeout(_timeout);
  }

  @override
  build(arg) async {
    ref.watch(metadataPluginProvider);
    final availability = ref.watch(_relatedArtistsAvailabilityProvider);

    // An empty page, not an error: the section hides itself on either, and
    // this way nothing is logged once per artist page for a failure already
    // reported once.
    if (availability.unavailable) return _none;

    try {
      return await fetch(0, 20);
    } catch (_) {
      availability.unavailable = true;
      rethrow;
    }
  }
}

final metadataPluginArtistRelatedArtistsProvider = AsyncNotifierProviderFamily<
    MetadataPluginArtistRelatedArtistsNotifier,
    SonolythPaginationResponseObject<SonolythFullArtistObject>,
    String>(
  () => MetadataPluginArtistRelatedArtistsNotifier(),
);
