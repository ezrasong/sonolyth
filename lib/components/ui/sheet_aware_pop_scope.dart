import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/extensions/context.dart';

/// System BACK on a **pushed** page: close an open sheet first, otherwise pop.
///
/// §29a fixed this for the pages that already intercepted back (Search, Stats,
/// Library, the player) — a shadcn `openDrawer` sheet is an overlay whose own
/// `PopScope` lives in the root route, which auto_route's nested router never
/// consults, so BACK reached the *page* instead and left the sheet floating.
/// A pushed page with no handler at all has the same fault by a different
/// route: nothing intercepts, the nested navigator pops the page, and the
/// sheet is stranded over whatever is underneath. Every collection page
/// (album, playlist, liked songs), the artist page and the local folder page
/// were in that state — each of them opens a track-options or header sheet.
///
/// `canPop: false` + an explicit `Navigator.pop` is the only shape that works:
/// `maybePop` would consult this same `PopScope` again.
class SheetAwarePopScope extends StatelessWidget {
  const SheetAwarePopScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // auto_route also fires this while it swaps routes; only the
        // intercepted system back (didPop false) is ours.
        if (didPop) return;
        if (context.closeOpenDrawer()) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      },
      child: child,
    );
  }
}
