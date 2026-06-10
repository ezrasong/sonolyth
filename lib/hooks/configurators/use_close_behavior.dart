import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/hooks/configurators/use_window_listener.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';

import 'package:local_notifier/local_notifier.dart';
import 'package:sonolyth/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

final closeNotification = !kIsDesktop
    ? null
    : (LocalNotification(
        title: 'Sonolyth',
        body: 'Running in background. Minimized to System Tray',
        actions: [
          LocalNotificationAction(text: 'Close The App'),
        ],
      )..onClickAction = (value) {
        exit(0);
      });

void useCloseBehavior(WidgetRef ref) {
  useWindowListener(
    onWindowClose: () async {
      final preferences = ref.read(userPreferencesProvider);
      if (preferences.closeBehavior == CloseBehavior.minimizeToTray) {
        await windowManager.hide();
        closeNotification?.show();
      } else {
        exit(0);
      }
    },
  );
}
