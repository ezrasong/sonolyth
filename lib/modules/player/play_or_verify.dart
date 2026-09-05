import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/modules/settings/playback/zarz_verify_dialog.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

/// What the transport's **play** button does, on both bars.
///
/// Normally it resumes. While §43's gate is holding a queue out of mpv there
/// is nothing to resume — mpv's playlist is empty — so `resume()` returned
/// silently, raised no exception and logged nothing: the play button was the
/// one control on the player that neither worked nor said why, sitting beside
/// a meta chip already offering "Verify lossless" (item 65).
///
/// It routes to that same dialog instead. This is not the transport quietly
/// becoming a different button: a press means "start this", verification is
/// the only thing that can make starting possible, and
/// [AudioPlayerNotifier.playDeferredQueue] marks the queue so a granted
/// challenge starts it rather than handing it over paused. The name the
/// button carries changes with it ([playActionLabel]), so nothing is
/// disguised — a screen reader is told it verifies, not that it plays.
///
/// The media notification and the hardware media keys are deliberately left
/// alone: they reach `resume()` with no `BuildContext` to open a dialog from,
/// and the toast from `use_zarz_verify_prompt.dart` is what speaks there.
Future<void> playOrVerify(BuildContext context, WidgetRef ref) async {
  final player = ref.read(audioPlayerProvider.notifier);
  if (!player.hasDeferredQueue) {
    await audioPlayer.resume();
    return;
  }
  await player.playDeferredQueue(() => verifyLosslessAccess(context, ref));
}

/// The tooltip and accessibility name for the play/pause control.
///
/// Hardcoded English in the deferred case, like the rest of this feature —
/// the toast, the dialog, its button and the meta chip all are (§42a). One
/// translated string out of six is worse than none.
String playActionLabel(
  BuildContext context, {
  required bool playing,
  required bool deferred,
}) {
  if (playing) return context.l10n.pause_playback;
  if (deferred) return "Verify lossless";
  return context.l10n.resume_playback;
}
