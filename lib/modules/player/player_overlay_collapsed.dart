import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/material.dart' as material;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:sonolyth/collections/intents.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/modules/player/player_track_details.dart';
import 'package:sonolyth/modules/root/sonolyth_navigation_bar.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/audio_player/querying_track_info.dart';
import 'package:sonolyth/provider/audio_player/smart_shuffle.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

class PlayerOverlayCollapsedSection extends HookConsumerWidget {
  final PanelController panelController;
  const PlayerOverlayCollapsedSection({
    super.key,
    required this.panelController,
  });

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final canShow = playlist.activeTrack != null;

    final isFetchingActiveTrack = ref.watch(queryingTrackInfoProvider);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;

    final shouldShow = useState(true);

    // Swipe-down dismissal: the bar follows the finger, fading as it goes;
    // past the threshold it slides out and playback stops.
    final dragY = useState<double>(0);
    final dragging = useState(false);

    ref.listen(navigationPanelHeight, (_, height) {
      shouldShow.value = height.ceil() == 50;
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: canShow && shouldShow.value
          ? GestureDetector(
              // Drag down to stop playback and clear the queue; flick up
              // still expands the full player like the panel drag would.
              onVerticalDragStart: (_) => dragging.value = true,
              onVerticalDragUpdate: (details) {
                dragY.value = (dragY.value + details.delta.dy)
                    .clamp(0.0, 90.0)
                    .toDouble();
              },
              onVerticalDragCancel: () {
                dragging.value = false;
                dragY.value = 0;
              },
              onVerticalDragEnd: (details) async {
                final velocity = details.primaryVelocity ?? 0;
                dragging.value = false;
                if (velocity > 250 || dragY.value > 45) {
                  // Finish the slide before stopping so the bar visibly
                  // leaves instead of vanishing in place.
                  dragY.value = 90;
                  await Future.delayed(const Duration(milliseconds: 150));
                  await ref.read(audioPlayerProvider.notifier).stop();
                  dragY.value = 0;
                } else {
                  dragY.value = 0;
                  if (velocity < -250) {
                    panelController.open();
                  }
                }
              },
              child: ClipRect(
                child: AnimatedSlide(
                  offset: Offset(0, dragY.value / 63),
                  duration: dragging.value
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: 1 - (dragY.value / 90) * 0.7,
                    duration: dragging.value
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: material.Material(
                        color: context.theme.colorScheme.card,
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.theme.colorScheme.border,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          panelController.open();
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          color: Colors.transparent,
                                          child: PlayerTrackDetails(
                                            track: playlist.activeTrack,
                                            color: context
                                                .theme.colorScheme.foreground,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Consumer(
                                          builder: (context, ref, _) {
                                            final shuffled = ref.watch(
                                              audioPlayerProvider
                                                  .select((s) => s.shuffled),
                                            );
                                            final smartShuffle =
                                                ref.watch(smartShuffleProvider);
                                            return IconButton.ghost(
                                              icon: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Icon(
                                                    SonolythIcons.shuffle,
                                                    size: 18,
                                                    color:
                                                        shuffled || smartShuffle
                                                            ? context
                                                                .theme
                                                                .colorScheme
                                                                .primary
                                                            : context
                                                                .theme
                                                                .colorScheme
                                                                .foreground,
                                                  ),
                                                  if (smartShuffle)
                                                    Positioned(
                                                      right: -5,
                                                      top: -5,
                                                      child: Icon(
                                                        SonolythIcons.lightning,
                                                        size: 10,
                                                        color: context
                                                            .theme
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              onPressed: () =>
                                                  cycleShuffleMode(ref),
                                            );
                                          },
                                        ),
                                        IconButton.ghost(
                                          icon: Icon(
                                            SonolythIcons.skipBack,
                                            color: context
                                                .theme.colorScheme.foreground,
                                          ),
                                          onPressed: audioPlayer.skipToPrevious,
                                        ),
                                        Consumer(
                                          builder: (context, ref, _) {
                                            return IconButton.ghost(
                                              icon: isFetchingActiveTrack
                                                  ? SizedBox(
                                                      height: 20,
                                                      width: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: context.theme
                                                            .colorScheme
                                                            .foreground,
                                                      ),
                                                    )
                                                  : Icon(
                                                      playing
                                                          ? SonolythIcons.pause
                                                          : SonolythIcons.play,
                                                      color: context
                                                          .theme
                                                          .colorScheme
                                                          .foreground,
                                                    ),
                                              onPressed: Actions.handler<
                                                  PlayPauseIntent>(
                                                context,
                                                PlayPauseIntent(ref),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton.ghost(
                                          icon: Icon(
                                            SonolythIcons.skipForward,
                                            color: context
                                                .theme.colorScheme.foreground,
                                          ),
                                          onPressed: audioPlayer.skipToNext,
                                        ),
                                        Consumer(
                                          builder: (context, ref, _) {
                                            final loopMode = ref.watch(
                                              audioPlayerProvider
                                                  .select((s) => s.loopMode),
                                            );
                                            return IconButton.ghost(
                                              icon: Icon(
                                                loopMode == PlaylistMode.single
                                                    ? SonolythIcons.repeatOne
                                                    : SonolythIcons.repeat,
                                                size: 18,
                                                color: loopMode !=
                                                        PlaylistMode.none
                                                    ? context.theme.colorScheme
                                                        .primary
                                                    : context.theme.colorScheme
                                                        .foreground,
                                              ),
                                              onPressed: () =>
                                                  audioPlayer.setLoopMode(
                                                switch (loopMode) {
                                                  PlaylistMode.loop =>
                                                    PlaylistMode.single,
                                                  PlaylistMode.single =>
                                                    PlaylistMode.none,
                                                  PlaylistMode.none =>
                                                    PlaylistMode.loop,
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                        const Gap(5),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
