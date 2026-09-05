import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/fake.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/ui/zenith_header_overlay.dart';
import 'package:sonolyth/components/ui/zenith_list_header.dart';
import 'package:sonolyth/components/ui/zenith_pro_icons.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/pages/artist/section/use_artist_playback.dart';
import 'package:sonolyth/provider/audio_player/smart_shuffle.dart';
import 'package:sonolyth/provider/blacklist_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/artist.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/provider/metadata_plugin/library/artists.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/utils/primitive_utils.dart';

/// The artist page under the same Header Overlay every other collection wears.
///
/// It was the one screen no Zenith pass ever reached (§29e): a bordered shadcn
/// `Card` with an "Artist" `OutlineBadge`, a white `Button.primary` "Follow"
/// pill and a red unfollow glyph — three idioms the rest of the app dropped in
/// §12, §19 and §20. Poweramp has no notion of following an artist and its
/// header carries no such controls, so follow, blacklist and share move into
/// the `header_menu` beside shuffle and play, exactly where the collection
/// header keeps "save to library".
class ArtistPageHeader extends HookConsumerWidget {
  final String artistId;
  const ArtistPageHeader({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, ref) {
    final colorScheme = context.theme.colorScheme;
    final isWide = MediaQuery.sizeOf(context).mdAndUp;

    final artistQuery = ref.watch(metadataPluginArtistProvider(artistId));
    final artist = artistQuery.asData?.value ?? FakeData.artist;

    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);
    ref.watch(blacklistProvider);
    final blacklistNotifier = ref.watch(blacklistProvider.notifier);
    final isBlackListed = blacklistNotifier.containsArtist(artist.id);

    final isFollowingQuery = ref.watch(
      metadataPluginIsSavedArtistProvider(artist.id),
    );
    final following = isFollowingQuery.asData?.value ?? false;
    final canFollow = authenticated.asData?.value == true;

    final playback = useArtistPlayback(ref, artistId);
    final isShuffled =
        useStream(audioPlayer.shuffledStream).data ?? audioPlayer.isShuffled;
    final smartShuffle = ref.watch(smartShuffleProvider);

    final image = artist.images.asUrlString(
      placeholder: ImagePlaceholder.artist,
    );

    // `ItemTrackMeta`: the genres carry line 2, the follower count the meta
    // line — the two facts the page actually knows before its lists load.
    final genres = (artist.genres ?? const <String>[])
        .map((genre) => genre.trim())
        .where((genre) => genre.isNotEmpty)
        .toList();
    final metaParts = <String>[
      if (artist.followers != null)
        context.l10n.followers(
          PrimitiveUtils.toReadableNumber(artist.followers!.toDouble()),
        ),
      if (isBlackListed) context.l10n.blacklisted,
    ];

    final shuffleActive = playback.isActive && (isShuffled || smartShuffle);
    final shuffleButton = ZenithHeaderButton(
      tooltip: playback.isActive && smartShuffle
          ? context.l10n.smart_shuffle
          : playback.isActive
              ? context.l10n.unshuffle_playlist
              : context.l10n.shuffle,
      glyph: ZenithHeaderGlyph.shuffle,
      selected: shuffleActive,
      loading: playback.isShuffleLoading,
      enabled: playback.hasTracks && !playback.isLoading,
      onPressed:
          playback.isActive ? () => cycleShuffleMode(ref) : playback.onShuffle,
    );

    final isPlayingHere = playback.isActive && playback.playing;
    final playButton = ZenithHeaderButton(
      tooltip: isPlayingHere ? context.l10n.pause : context.l10n.play,
      glyph: isPlayingHere ? null : ZenithHeaderGlyph.play,
      icon: isPlayingHere ? SonolythIcons.pause : null,
      loading: playback.isPlayLoading,
      enabled: playback.hasTracks && !playback.isLoading,
      onPressed: playback.isActive
          ? () => playback.playing ? audioPlayer.pause() : audioPlayer.resume()
          : playback.onPlay,
    );

    Future<void> onFollow() async {
      final notifier = ref.read(metadataPluginSavedArtistsProvider.notifier);
      if (following) {
        await notifier.removeFavorite([artist]);
      } else {
        await notifier.addFavorite([artist]);
      }
    }

    Future<void> onBlacklist() async {
      final notifier = ref.read(blacklistProvider.notifier);
      if (isBlackListed) {
        await notifier.remove(artist.id);
      } else {
        await notifier.add(
          BlacklistTableCompanion.insert(
            name: artist.name,
            elementId: artist.id,
            elementType: BlacklistedType.artist,
          ),
        );
      }
    }

    Future<void> onShare() async {
      await Clipboard.setData(ClipboardData(text: artist.externalUri));
      if (!context.mounted) return;
      showToast(
        context: context,
        location: ToastLocation.topRight,
        dismissible: true,
        builder: (context, overlay) => SurfaceCard(
          child:
              Text(context.l10n.artist_url_copied, textAlign: TextAlign.center),
        ),
      );
    }

    final menuButton = SizedBox(
      width: ZenithListHeaderMetrics.menuButtonWidth,
      height: ZenithListHeaderMetrics.menuButtonSize,
      child: AdaptivePopSheetList<String>(
        tooltip: context.l10n.more_actions,
        items: (context) => [
          if (canFollow && isFollowingQuery.hasValue)
            AdaptiveMenuButton(
              value: "follow",
              leading: Icon(
                following ? SonolythIcons.heartFilled : SonolythIcons.heart,
              ),
              child: Text(
                following ? context.l10n.following : context.l10n.follow,
              ),
            ),
          AdaptiveMenuButton(
            value: "blacklist",
            leading: const Icon(SonolythIcons.userRemove),
            child: Text(
              isBlackListed
                  ? context.l10n.remove_from_blacklist
                  : context.l10n.add_artist_to_blacklist,
            ),
          ),
          AdaptiveMenuButton(
            value: "share",
            leading: const Icon(SonolythIcons.share),
            child: Text(context.l10n.share),
          ),
        ],
        icon: ZenithHeaderMenuIcon(
          size: ZenithListHeaderMetrics.menuGlyphSize,
          color: colorScheme.primary,
        ),
        onSelected: (value) {
          switch (value) {
            case "follow":
              onFollow();
            case "blacklist":
              onBlacklist();
            case "share":
              onShare();
          }
        },
      ),
    );

    return ZenithHeaderOverlay(
      image: image,
      parentLabel: context.l10n.artists,
      title: artist.name,
      line2: genres.isEmpty ? null : genres.join(", "),
      metaParts: metaParts,
      height: isWide
          ? ZenithHeaderMetrics.wideHeight
          : ZenithHeaderMetrics.phoneHeight,
      buttons: [shuffleButton, playButton],
      menu: menuButton,
    );
  }
}
