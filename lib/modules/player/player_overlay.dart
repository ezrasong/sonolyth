import 'package:audio_service/audio_service.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:sonolyth/modules/player/player_overlay_collapsed.dart';

import 'package:sonolyth/modules/root/sonolyth_navigation_bar.dart';
import 'package:sonolyth/modules/player/player.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';

final playerOverlayControllerProvider = StateProvider<PanelController>((ref) {
  return PanelController();
});

class PlayerOverlay extends HookConsumerWidget {
  final String albumArt;

  const PlayerOverlay({
    required this.albumArt,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final activeTrack =
        ref.watch(audioPlayerProvider.select((s) => s.activeTrack));
    final canShow = activeTrack != null;

    final screenSize = MediaQuery.sizeOf(context);

    final panelController = ref.watch(playerOverlayControllerProvider);

    // Tapping the media notification expands the full player. The stream is a
    // BehaviorSubject, so a cold start from the notification replays `true`
    // once this overlay mounts; the post-frame hop waits for the panel to be
    // attached before opening it.
    useEffect(() {
      final subscription = AudioService.notificationClicked.listen((clicked) {
        if (!clicked) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (panelController.isAttached && !panelController.isPanelOpen) {
            panelController.open();
          }
        });
      });
      return subscription.cancel;
    }, [panelController]);

    return SlidingUpPanel(
      maxHeight: screenSize.height,
      backdropEnabled: false,
      minHeight: canShow ? 63 : 0,
      onPanelSlide: (position) {
        final invertedPosition = 1 - position;
        ref.read(navigationPanelHeight.notifier).state = 50 * invertedPosition;
      },
      controller: panelController,
      color: Colors.transparent,
      parallaxEnabled: true,
      renderPanelSheet: false,
      header: SizedBox(
        height: 63,
        width: screenSize.width,
        child: PlayerOverlayCollapsedSection(panelController: panelController),
      ),
      panelBuilder: (scrollController) => PlayerView(
        panelController: panelController,
        scrollController: scrollController,
      ),
    );
  }
}
