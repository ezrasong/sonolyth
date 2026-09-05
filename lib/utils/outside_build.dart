import 'package:flutter/scheduler.dart';

/// Runs [action] where it is legal to mark a widget as needing to build.
///
/// Riverpod listeners registered with `fireImmediately: true` from inside a
/// `useEffect` run in flutter_hooks' `didBuild` — i.e. still inside
/// `Element.performRebuild`, the framework's build phase. Anything that shows
/// an overlay from there (`showToast`, `showDialog`) marks a widget dirty
/// mid-build, and Flutter logs "… cannot be marked as needing to build because
/// the framework is already in the process of building widgets". The overlay
/// still appears, so the effect is nil — but a widget marked dirty during a
/// build is only ever right by accident.
///
/// A post-frame callback is used **only** when a frame is actually in flight.
/// Registered at any other time it waits for the next frame, which an idle app
/// has no reason to schedule; a prompt that arrives whenever something else
/// happens to repaint is worse than one raised a moment early.
void runOutsideBuild(void Function() action) {
  final phase = SchedulerBinding.instance.schedulerPhase;
  final building = phase == SchedulerPhase.persistentCallbacks ||
      phase == SchedulerPhase.midFrameMicrotasks;
  if (!building) {
    action();
    return;
  }
  SchedulerBinding.instance.addPostFrameCallback((_) => action());
}
