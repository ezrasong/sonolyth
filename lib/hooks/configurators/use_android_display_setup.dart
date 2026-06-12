import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/utils/platform.dart';

/// Applies the Android display setup — high refresh rate and portrait lock
/// (in landscape the width crosses the desktop breakpoint and the app flips
/// into the sidebar layout mid-use).
///
/// Both calls require an attached activity, so they run on resume instead of
/// in main(): when AudioService boots the engine headlessly (media-button
/// press after the process died) there is no activity yet, and failing in
/// main() before runApp leaves a permanently black screen.
void useAndroidDisplaySetup() {
  useEffect(() {
    if (!kIsAndroid) return null;

    Future<void> apply() async {
      try {
        await FlutterDisplayMode.setHighRefreshRate();
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    }

    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      apply();
    }
    final listener = AppLifecycleListener(onResume: apply);
    return listener.dispose;
  }, []);
}
