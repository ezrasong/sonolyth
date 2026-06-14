import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in toggle for resolving playback through the native Qobuz audio source
/// (ISRC-exact, lossless) ahead of the YouTube plugin, which stays as the
/// fallback for tracks Qobuz doesn't carry.
///
/// Stored in SharedPreferences rather than the player-state DB so it needs no
/// drift migration. Defaults to off, so existing YouTube-only playback is
/// unchanged until the user enables it.
const _prefsKey = "qobuz-playback-enabled";

class QobuzPlaybackEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_prefsKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_prefsKey, enabled);
    state = AsyncData(enabled);
  }
}

final qobuzPlaybackEnabledProvider =
    AsyncNotifierProvider<QobuzPlaybackEnabledNotifier, bool>(
  QobuzPlaybackEnabledNotifier.new,
);
