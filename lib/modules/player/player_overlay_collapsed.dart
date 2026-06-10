import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/material.dart' as material;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:sonolyth/collections/intents.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/modules/player/player_track_details.dart';
import 'package:sonolyth/modules/root/sonolyth_navigation_bar.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/audio_player/querying_track_info.dart';
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

    ref.listen(navigationPanelHeight, (_, height) {
      shouldShow.value = height.ceil() == 50;
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: canShow && shouldShow.value
          ? Padding(
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    color: context.theme.colorScheme.foreground,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton.ghost(
                                  icon: Icon(
                                    SonolythIcons.skipBack,
                                    color: context.theme.colorScheme.foreground,
                                  ),
                                  onPressed: isFetchingActiveTrack
                                      ? null
                                      : audioPlayer.skipToPrevious,
                                ),
                                Consumer(
                                  builder: (context, ref, _) {
                                    return IconButton.ghost(
                                      icon: isFetchingActiveTrack
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : Icon(
                                              playing
                                                  ? SonolythIcons.pause
                                                  : SonolythIcons.play,
                                              color: context
                                                  .theme.colorScheme.foreground,
                                            ),
                                      onPressed:
                                          Actions.handler<PlayPauseIntent>(
                                        context,
                                        PlayPauseIntent(ref),
                                      ),
                                    );
                                  },
                                ),
                                IconButton.ghost(
                                  icon: Icon(
                                    SonolythIcons.skipForward,
                                    color: context.theme.colorScheme.foreground,
                                  ),
                                  onPressed: isFetchingActiveTrack
                                      ? null
                                      : audioPlayer.skipToNext,
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
            )
          : const SizedBox.shrink(),
    );
  }
}
