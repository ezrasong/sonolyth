import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/heart_button/heart_button.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/dialogs/confirm_download_dialog.dart';
import 'package:sonolyth/components/track_presentation/presentation_props.dart';
import 'package:sonolyth/components/track_presentation/use_action_callbacks.dart';
import 'package:sonolyth/components/track_presentation/use_is_user_playlist.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/playlist/playlist_create_dialog.dart';
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
    final collectionLabel = switch (options.collection) {
      SonolythSimpleAlbumObject() => "Album",
      SonolythSimplePlaylistObject() => "Playlist",
      _ => "Playlist",
    };

    final decorationImage = DecorationImage(
      image: UniversalImage.imageProvider(options.image),
      fit: BoxFit.cover,
    );

    final imageDimension = mediaQuery.mdAndUp ? 200 : 120;

    final (:isLoading, :isActive, :onPlay, :onShuffle, :onAddToQueue) =
        useActionCallbacks(ref);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;
    ref.watch(downloadManagerProvider);
    final downloader = ref.read(downloadManagerProvider.notifier);

    Future<void> onDownloadAll() async {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => const ConfirmDownloadDialog(),
          ) ??
          false;
      if (!confirmed) return;

      final tracks = options.tracks.isEmpty
          ? await options.pagination.onFetchAll()
          : options.tracks;
      final fullTracks = tracks.whereType<SonolythFullTrackObject>().toList();
      if (fullTracks.isEmpty) return;

      downloader.addAllToQueue(
        fullTracks,
        collectionUrl: options.shareUrl,
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

    final playbackActions = Row(
      spacing: 8 * scale,
      children: [
        Tooltip(
          tooltip: TooltipContainer(
            child: Text(context.l10n.download_all),
          ).call,
          child: IconButton.outline(
            icon: const Icon(SonolythIcons.download),
            shape: ButtonShape.circle,
            enabled: !options.pagination.isLoading,
            onPressed: onDownloadAll,
          ),
        ),
        Tooltip(
          tooltip: TooltipContainer(
            child: Text(context.l10n.shuffle_playlist),
          ).call,
          child: IconButton.ghost(
            icon: isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(onSurface: false, size: 20),
                  )
                : const Icon(SonolythIcons.shuffle),
            shape: ButtonShape.circle,
            enabled: !isLoading && !isActive,
            onPressed: onShuffle,
          ),
        ),
        if (mediaQuery.width <= 320)
          Tooltip(
            tooltip: TooltipContainer(
              child: Text(context.l10n.add_to_queue),
            ).call,
            child: IconButton.secondary(
              icon: const Icon(SonolythIcons.queueAdd),
              shape: ButtonShape.circle,
              enabled: !isLoading && !isActive,
              onPressed: onAddToQueue,
            ),
          )
        else
          IconButton.ghost(
            icon: const Icon(SonolythIcons.queueAdd),
            shape: ButtonShape.circle,
            enabled: !isLoading && !isActive,
            onPressed: onAddToQueue,
          ),
        Tooltip(
          tooltip: TooltipContainer(
            child: isActive && playing
                ? Text(context.l10n.pause)
                : Text(context.l10n.play),
          ).call,
          child: IconButton.primary(
            size: ButtonSize.large,
            shape: ButtonShape.circle,
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
                ? () =>
                    playing ? audioPlayer.pause() : audioPlayer.resume()
                : onPlay,
            enabled: !isLoading,
          ),
        ),
      ],
    );

    final additionalActions = Row(
      spacing: 8 * scale,
      children: [
        if (isUserPlaylist)
          IconButton.outline(
            size: ButtonSize.small,
            icon: const Icon(SonolythIcons.edit),
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
        if (options.shareUrl != null)
          Tooltip(
            tooltip: TooltipContainer(
              child: Text(context.l10n.share),
            ).call,
            child: IconButton.outline(
              icon: const Icon(SonolythIcons.share),
              size: ButtonSize.small,
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
          ),
        if (options.onHeart != null)
          HeartButton(
            isLiked: options.isLiked,
            tooltip: options.isLiked
                ? context.l10n.remove_from_favorites
                : context.l10n.save_as_favorite,
            variance: ButtonVariance.outline,
            size: ButtonSize.small,
            onPressed: options.onHeart,
          ),
      ],
    );

    return SliverMainAxisGroup(
      slivers: [
        if (mediaQuery.mdAndUp) SliverGap(16 * scale),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: (mediaQuery.mdAndUp ? 16 : 8.0) * scale,
          ),
          sliver: SliverList.list(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  16 * scale,
                  40 * scale,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 20 * scale,
                  children: [
                    Row(
                      spacing: 18 * scale,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          height: imageDimension * scale,
                          width: imageDimension * scale,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4 * scale),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(120),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                            image: decorationImage,
                          ),
                        ),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                collectionLabel,
                                style: context.theme.typography.small.copyWith(
                                  color: context.theme.colorScheme.foreground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              AutoSizeText(
                                options.title,
                                maxLines: 2,
                                minFontSize: 28,
                                maxFontSize: mediaQuery.mdAndUp ? 54 : 34,
                                overflow: TextOverflow.ellipsis,
                                style: context.theme.typography.h1.copyWith(
                                  color: context.theme.colorScheme.foreground,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (options.description != null)
                                AutoSizeText(
                                  options.description!,
                                  maxLines: 2,
                                  minFontSize: 12,
                                  maxFontSize: 14,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context
                                        .theme.colorScheme.mutedForeground,
                                    fontSize: 14,
                                  ),
                                ),
                              const Gap(8),
                              Flex(
                                // Vertical (phone) layout must stay
                                // left-aligned with the title above it;
                                // centering only makes sense horizontally.
                                crossAxisAlignment: mediaQuery.smAndUp
                                    ? CrossAxisAlignment.center
                                    : CrossAxisAlignment.start,
                                direction: mediaQuery.smAndUp
                                    ? Axis.horizontal
                                    : Axis.vertical,
                                spacing: 8 * scale,
                                children: [
                                  if (options.owner != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (options.ownerImage != null)
                                          Avatar(
                                            initials: options.owner?[0] ?? "U",
                                            provider:
                                                UniversalImage.imageProvider(
                                              options.ownerImage!,
                                            ),
                                            size: 20 * scale,
                                          ),
                                        if (options.ownerImage != null)
                                          const Gap(6),
                                        Flexible(
                                          child: Text(
                                            options.owner!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: context
                                                  .theme.colorScheme.foreground,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ).small(),
                                        ),
                                      ],
                                    ),
                                  additionalActions,
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: playbackActions,
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
