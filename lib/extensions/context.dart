import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/l10n/l10n.dart';

extension AppLocale on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension AppOverlays on BuildContext {
  /// Closes the topmost shadcn drawer / bottom sheet (`openDrawer`,
  /// `openSheet`) open above this context, and says whether there was one.
  ///
  /// Those overlays are not routes: the root `Scaffold`'s `DrawerOverlay`
  /// re-parents the whole page tree under one `DrawerEntryWidget` per open
  /// sheet (newest outermost) and would dismiss the top one from its own
  /// `PopScope` — but that `PopScope` sits in the root route, and a system
  /// back inside auto_route's nested router only ever reaches the *page's*
  /// `PopScope`. So a page that intercepts back (Search, Library, Stats →
  /// Home) has to do the dismissing itself, and must not leave the page on
  /// a press that was meant to close the sheet.
  bool closeOpenDrawer() {
    DrawerEntryWidgetState? top;
    visitAncestorElements((element) {
      if (element is StatefulElement &&
          element.state is DrawerEntryWidgetState) {
        top = element.state as DrawerEntryWidgetState;
      }
      return true;
    });
    if (top == null) return false;
    top!.close();
    return true;
  }
}
