import 'dart:ui';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sonolyth/collections/fake.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_card.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/album/album_card.dart';
import 'package:sonolyth/modules/artist/artist_card.dart';
import 'package:sonolyth/modules/playlist/playlist_card.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class HorizontalPlaybuttonCardView<T> extends HookWidget {
  final Widget title;
  final List<T> items;
  final Widget? error;
  final VoidCallback onFetchMore;
  final bool isLoadingNextPage;
  final bool hasNextPage;
  final Widget? titleTrailing;

  HorizontalPlaybuttonCardView({
    required this.title,
    required this.items,
    required this.hasNextPage,
    required this.onFetchMore,
    required this.isLoadingNextPage,
    this.titleTrailing,
    this.error,
    super.key,
  }) : assert(
          items.every(
            (item) =>
                item is SonolythSimpleAlbumObject ||
                item is SonolythSimplePlaylistObject ||
                item is SonolythFullArtistObject,
          ),
        );

  @override
  Widget build(BuildContext context) {
    final scrollController = useScrollController();
    final isArtist = items.every((s) => s is SonolythFullArtistObject);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: DefaultTextStyle(
                  // `SubheadText` — 12sp bold at 60%. Small and dim on
                  // purpose; see `zenithSubhead`.
                  style: zenithSubhead(context.theme.colorScheme),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: title,
                ),
              ),
              if (titleTrailing != null) titleTrailing!,
            ],
          ),
          if (error != null)
            error!
          else
            SizedBox(
              // Card contents scale with theme.scaling *and* with the system
              // font size; the rail must too or increased UI scale clips every
              // carousel (§37).
              // One height for every card type: since ArtistCard became a
              // `PlaybuttonCard` too (§34) an artist rail is exactly as tall
              // as an album rail — it used to need 25dp more for the 130dp
              // avatar and the "ARTIST" badge.
              height: ZenithCardMetrics.extent(context),
              child: NotificationListener(
                // disable multiple scrollbar to use this
                onNotification: (notification) => true,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: PointerDeviceKind.values.toSet(),
                  ),
                  child: items.isEmpty
                      // Placeholder cards must read as skeletons and never be
                      // tappable — otherwise they navigate to FakeData routes.
                      ? Skeletonizer(
                          enabled: true,
                          child: IgnorePointer(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 5,
                              itemBuilder: (context, index) {
                                return AlbumCard(FakeData.albumSimple);
                              },
                            ),
                          ),
                        )
                      : InfiniteList(
                          scrollController: scrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          itemCount: items.length,
                          onFetchData: onFetchMore,
                          loadingBuilder: (context) => Skeletonizer(
                                enabled: true,
                                child: isArtist
                                    ? ArtistCard(FakeData.artist)
                                    : AlbumCard(FakeData.albumSimple),
                              ),
                          isLoading: isLoadingNextPage,
                          hasReachedMax: !hasNextPage,
                          // No separator: the cards carry
                          // `ItemTrackAAImage_scene_grid`'s 8dp margins.
                          separatorBuilder: (context, index) =>
                              const SizedBox.shrink(),
                          itemBuilder: (context, index) {
                            final item = items[index];

                            return switch (item) {
                              SonolythSimplePlaylistObject() => PlaylistCard(
                                  item as SonolythSimplePlaylistObject),
                              SonolythSimpleAlbumObject() =>
                                AlbumCard(item as SonolythSimpleAlbumObject),
                              SonolythFullArtistObject() =>
                                ArtistCard(item as SonolythFullArtistObject),
                              _ => const SizedBox.shrink(),
                            };
                          }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
