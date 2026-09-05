import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sonolyth/collections/assets.gen.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/player/player_overlay.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';

/// The footer slot that holds playback: always the phone's sliding
/// [PlayerOverlay], at every width.
///
/// It used to branch. Above 820dp (or whenever the Layout Mode setting said
/// "extended") this drew a desktop three-column bar instead — art and titles,
/// the transport, then the actions over a 250dp volume slider — the partner of
/// the desktop sidebar. Both are gone (§38): Poweramp has no wide layout to
/// replicate, `layout-sw600dp` in the decompiled tree is two Material
/// snackbars and `layout-land` is its billing screens, and the desktop
/// platforms were deleted when the fork was established. Keeping the bar
/// without the sidebar would have left every width above 820dp with a desktop
/// player bar, no sidebar and no navbar.
///
/// This stays a widget rather than folding into `root_app.dart` because the
/// overlay wants the active track's largest cover, and that is a `useMemoized`
/// on the track.
class BottomPlayer extends HookConsumerWidget {
  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final activeTrack =
        ref.watch(audioPlayerProvider.select((s) => s.activeTrack));

    final albumArt = useMemoized(
      () => activeTrack?.album.images.isNotEmpty == true
          ? (activeTrack?.album.images).asUrlString(
              index: (activeTrack?.album.images.length ?? 1) - 1,
              placeholder: ImagePlaceholder.albumArt,
            )
          : Assets.images.albumPlaceholder.path,
      [activeTrack?.album.images],
    );

    // Returns an empty, non-spacious widget: the overlay itself lives in the
    // global overlay stack, not in this slot.
    return PlayerOverlay(albumArt: albumArt);
  }
}
