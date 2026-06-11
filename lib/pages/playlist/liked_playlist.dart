import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/collections/assets.gen.dart';
import 'package:sonolyth/components/track_presentation/presentation_props.dart';
import 'package:sonolyth/components/track_presentation/track_presentation.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/pages/playlist/playlist.dart';
import 'package:sonolyth/provider/metadata_plugin/library/tracks.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';

@RoutePage()
class LikedPlaylistPage extends HookConsumerWidget {
  static const name = PlaylistPage.name;

  final SonolythSimplePlaylistObject playlist;
  const LikedPlaylistPage({
    super.key,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context, ref) {
    final likedTracks = ref.watch(metadataPluginSavedTracksProvider);
    final likedTracksNotifier =
        ref.watch(metadataPluginSavedTracksProvider.notifier);
    final tracks = likedTracks.asData?.value.items ?? [];

    return material.RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(metadataPluginSavedTracksProvider);
      },
      child: TrackPresentation(
        options: TrackPresentationOptions(
          collection: playlist,
          image: Assets.images.likedTracks.path,
          pagination: PaginationProps(
            hasNextPage: likedTracks.asData?.value.hasMore ?? false,
            isLoading: likedTracks.isLoading || likedTracks.isLoadingNextPage,
            onFetchMore: () async {
              await likedTracksNotifier.fetchMore();
            },
            onFetchAll: () async {
              return await likedTracksNotifier.fetchAll();
            },
            onRefresh: () async {
              ref.invalidate(metadataPluginSavedTracksProvider);
            },
          ),
          title: playlist.name,
          description: playlist.description,
          tracks: tracks,
          error: likedTracks.error,
          routePath: '/playlist/${playlist.id}',
          isLiked: false,
          shareUrl: null,
          onHeart: null,
          owner: playlist.owner.name,
        ),
      ),
    );
  }
}
