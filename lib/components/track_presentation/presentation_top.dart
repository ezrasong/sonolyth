import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/heart_button/heart_button.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/track_presentation/presentation_props.dart';
import 'package:sonolyth/components/track_presentation/use_action_callbacks.dart';
import 'package:sonolyth/components/track_presentation/use_is_user_playlist.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/extensions/string.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:media_kit/media_kit.dart' show PlaylistMode;
import 'package:sonolyth/modules/playlist/playlist_create_dialog.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

class TrackPresentationTopSection extends HookConsumerWidget {
  const TrackPresentationTopSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.sizeOf(context);
    final options = TrackPresentationOptions.of(context);
    final scale = context.theme.scaling;
    final isUserPlaylist = useIsUserPlaylist(ref, options.collectionId);
    final isWide = mediaQuery.mdAndUp;
    final collectionLabel = switch (options.collection) {
      SonolythSimpleAlbumObject() => "Album",
      SonolythSimplePlaylistObject() => "Playlist",
      _ => "Playlist",
    };

    final decorationImage = DecorationImage(
      image: UniversalImage.imageProvider(options.image),
      fit: BoxFit.cover,
    );

    // Wide screens keep the artwork beside the title; on phones it becomes a
    // large centred hero (Spotify-style), so it can take more of the width.
    final imageDimension =
        isWide ? 200.0 : (mediaQuery.width * 0.56).clamp(160.0, 260.0);

    final (:isLoading, :isActive, :onPlay, :onShuffle, :onAddToQueue) =
        useActionCallbacks(ref);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;
    ref.watch(downloadManagerProvider);
    final downloader = ref.read(downloadManagerProvider.notifier);

    Future<void> onDownloadAll() async {
      final tracks = options.tracks.isEmpty
          ? await options.pagination.onFetchAll()
          : options.tracks;
      final fullTracks = tracks.whereType<SonolythFullTrackObject>().toList();
      if (fullTracks.isEmpty) return;

      downloader.addAllToQueue(
        fullTracks,
        collectionUrl: options.shareUrl,
        collectionName: options.title,
      );
      if (!context.mounted) return;
      showToast(
        context: context,
        location: ToastLocation.topRight,
        builder: (context, overlay) => SurfaceCard(
          child: Basic(
            leading: const Icon(SonolythIcons.download),
            title: Text(context.l10n.download_count(fullTracks.length)),
          ),
        ),
      );
    }

    // ---- Individual action buttons, composed differently per layout ----

    final downloadButton = Tooltip(
      tooltip: TooltipContainer(
        child: Text(context.l10n.download_all),
      ).call,
      child: IconButton.ghost(
        icon: const Icon(SonolythIcons.download),
        shape: ButtonShape.circle,
        enabled: !options.pagination.isLoading,
        onPressed: onDownloadAll,
      ),
    );

    final shuffleButton = Tooltip(
      tooltip: TooltipContainer(
        child: Text(context.l10n.shuffle_playlist),
      ).call,
      child: IconButton.ghost(
        icon: isLoading
            ? const Center(
                child: CircularProgressIndicator(onSurface: false, size: 20),
              )
            : const Icon(SonolythIcons.shuffle),
        shape: ButtonShape.circle,
        enabled: !isLoading && !isActive,
        onPressed: onShuffle,
      ),
    );

    final queueButton = Tooltip(
      tooltip: TooltipContainer(
        child: Text(context.l10n.add_to_queue),
      ).call,
      child: IconButton.ghost(
        icon: const Icon(SonolythIcons.queueAdd),
        shape: ButtonShape.circle,
        enabled: !isLoading && !isActive,
        onPressed: onAddToQueue,
      ),
    );

    final loopMode = ref.watch(audioPlayerProvider.select((s) => s.loopMode));
    final repeatButton = Tooltip(
      tooltip: TooltipContainer(
        child: Text(
          loopMode == PlaylistMode.single
              ? context.l10n.loop_track
              : context.l10n.repeat_playlist,
        ),
      ).call,
      child: IconButton.ghost(
        icon: Icon(
          loopMode == PlaylistMode.single
              ? SonolythIcons.repeatOne
              : SonolythIcons.repeat,
          color: loopMode != PlaylistMode.none
              ? context.theme.colorScheme.primary
              : null,
        ),
        shape: ButtonShape.circle,
        onPressed: () => audioPlayer.setLoopMode(
          switch (loopMode) {
            PlaylistMode.loop => PlaylistMode.single,
            PlaylistMode.single => PlaylistMode.none,
            PlaylistMode.none => PlaylistMode.loop,
          },
        ),
      ),
    );

    final playButton = Tooltip(
      tooltip: TooltipContainer(
        child: isActive && playing
            ? Text(context.l10n.pause)
            : Text(context.l10n.play),
      ).call,
      child: IconButton.primary(
        shape: ButtonShape.circle,
        size: isWide ? ButtonSize.large : const ButtonSize(1.3),
        icon: switch ((isActive, isLoading)) {
          (true, false) => Icon(
              playing ? SonolythIcons.pause : SonolythIcons.play,
            ),
          (false, true) => const Center(
              child: CircularProgressIndicator(onSurface: true, size: 18),
            ),
          _ => const Icon(SonolythIcons.play),
        },
        // When this collection is already playing, the button toggles
        // pause/resume instead of being disabled.
        onPressed: isActive
            ? () => playing ? audioPlayer.pause() : audioPlayer.resume()
            : onPlay,
        enabled: !isLoading,
      ),
    );

    final editButton = isUserPlaylist
        ? Tooltip(
            tooltip: TooltipContainer(
              child: Text(context.l10n.edit),
            ).call,
            child: IconButton.ghost(
              icon: const Icon(SonolythIcons.edit),
              shape: ButtonShape.circle,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return PlaylistCreateDialog(
                      playlistId: options.collectionId,
                      trackIds: options.tracks.map((e) => e.id).toList(),
                    );
                  },
                );
              },
            ),
          )
        : null;

    final shareButton = options.shareUrl == null
        ? null
        : Tooltip(
            tooltip: TooltipContainer(
              child: Text(context.l10n.share),
            ).call,
            child: IconButton.ghost(
              icon: const Icon(SonolythIcons.share),
              shape: ButtonShape.circle,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: options.shareUrl!),
                );
                if (!context.mounted) return;
                showToast(
                  context: context,
                  location: ToastLocation.topRight,
                  builder: (context, overlay) {
                    return SurfaceCard(
                      child: Text(
                        context.l10n
                            .copied_shareurl_to_clipboard(options.shareUrl!),
                      ).small(),
                    );
                  },
                );
              },
            ),
          );

    final heartButton = options.onHeart == null
        ? null
        : HeartButton(
            isLiked: options.isLiked,
            tooltip: options.isLiked
                ? context.l10n.remove_from_favorites
                : context.l10n.save_as_favorite,
            variance: ButtonVariance.ghost,
            onPressed: options.onHeart,
          );

    // Secondary (non-play) icons, shared across layouts.
    final secondaryActions = <Widget>[
      if (heartButton != null) heartButton,
      downloadButton,
      if (shareButton != null) shareButton,
      if (editButton != null) editButton,
      queueButton,
    ];
    // Split point used on phones to seat the Play button dead-centre, with the
    // secondary icons balanced to either side of it.
    final secondaryLeftCount = (secondaryActions.length / 2).ceil();

    final artwork = Container(
      height: imageDimension * scale,
      width: imageDimension * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(140),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
        image: decorationImage,
      ),
    );

    final cleanedDescription =
        options.description?.unescapeHtml().cleanHtml().trim();

    final titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6 * scale,
      children: [
        Text(
          collectionLabel,
          style: context.theme.typography.small.copyWith(
            color: context.theme.colorScheme.mutedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
        AutoSizeText(
          options.title,
          maxLines: 2,
          minFontSize: isWide ? 28 : 24,
          maxFontSize: isWide ? 54 : 34,
          overflow: TextOverflow.ellipsis,
          style: context.theme.typography.h1.copyWith(
            color: context.theme.colorScheme.foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
        // Only render a description when there's actually one — an empty string
        // would otherwise reserve a blank line and open a dead gap.
        if (cleanedDescription != null && cleanedDescription.isNotEmpty)
          AutoSizeText(
            cleanedDescription,
            maxLines: 2,
            minFontSize: 12,
            maxFontSize: 14,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.theme.colorScheme.mutedForeground,
              fontSize: 14,
            ),
          ),
      ],
    );

    final ownerRow = options.owner == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (options.ownerImage != null)
                Avatar(
                  initials: options.owner?[0] ?? "U",
                  provider: UniversalImage.imageProvider(
                    options.ownerImage!,
                  ),
                  size: 22 * scale,
                ),
              if (options.ownerImage != null) const Gap(8),
              Flexible(
                child: Text(
                  options.owner!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.theme.colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ).small(),
              ),
            ],
          );

    final header = isWide
        // Wide screens (tablet/desktop): artwork beside the title, controls
        // in a row beneath — matches the desktop player.
        ? Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 20 * scale,
            children: [
              Row(
                spacing: 18 * scale,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  artwork,
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 10 * scale,
                      children: [
                        titleBlock,
                        if (ownerRow != null) ownerRow,
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                spacing: 8 * scale,
                children: [
                  playButton,
                  ...secondaryActions,
                ],
              ),
            ],
          )
        // Phones: large centred artwork, left-aligned title/owner/description,
        // then an action bar with secondary icons on the left and shuffle +
        // a prominent Play on the right (Spotify-style).
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14 * scale,
            children: [
              Center(child: artwork),
              titleBlock,
              if (ownerRow != null) ownerRow,
              // Play sits dead-centre, flanked by shuffle (left) and repeat
              // (right); the secondary icons split evenly to the outer edges so
              // there's an equal number of controls on each side.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ...secondaryActions.take(secondaryLeftCount),
                  shuffleButton,
                  playButton,
                  repeatButton,
                  ...secondaryActions.skip(secondaryLeftCount),
                ],
              ),
            ],
          );

    return SliverMainAxisGroup(
      slivers: [
        if (isWide) SliverGap(16 * scale),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: (isWide ? 16 : 16.0) * scale,
          ),
          sliver: SliverList.list(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  16 * scale,
                  (isWide ? 40 : 22) * scale,
                  16 * scale,
                  20 * scale,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.theme.colorScheme.muted,
                      context.theme.colorScheme.background,
                    ],
                  ),
                ),
                child: header,
              ),
            ],
          ),
        )
      ],
    );
  }
}
