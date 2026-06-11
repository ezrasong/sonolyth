import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/widgets.dart';

import 'package:sonolyth/collections/routes.dart';
import 'package:sonolyth/components/dialogs/prompt_dialog.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/hooks/utils/use_async_effect.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/utils/platform.dart';

/// Asks (once) to exclude the app from battery optimization so playback
/// survives the screen turning off. The OS confirmation screens can't be
/// themed, but the explanation is shown in an app-styled dialog first
/// instead of dropping the raw system prompt on the user at first launch.
void useDisableBatteryOptimizations() {
  useAsyncEffect(() async {
    if (!kIsAndroid || KVStoreService.askedForBatteryOptimization) return;

    final alreadyDisabled =
        await DisableBatteryOptimization.isAllBatteryOptimizationDisabled ??
            false;
    if (alreadyDisabled) {
      await KVStoreService.setAskedForBatteryOptimization(true);
      return;
    }

    // The hook runs during app start — wait for the root navigator to be
    // ready before showing a dialog on it.
    BuildContext? context;
    for (var i = 0; i < 20; i++) {
      context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) break;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (context == null || !context.mounted) return;

    final confirmed = await showPromptDialog(
      context: context,
      title: context.l10n.background_playback,
      message: context.l10n.background_playback_explanation,
      okText: context.l10n.accept,
      cancelText: context.l10n.decline,
    );

    if (confirmed) {
      await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();

      final manufacturerDisabled = await DisableBatteryOptimization
              .isManufacturerBatteryOptimizationDisabled ??
          true;
      if (!manufacturerDisabled && context.mounted) {
        await DisableBatteryOptimization
            .showDisableManufacturerBatteryOptimizationSettings(
          context.l10n.background_playback,
          context.l10n.background_playback_manufacturer_hint,
        );
      }
    }

    await KVStoreService.setAskedForBatteryOptimization(true);
  }, null, []);
}
