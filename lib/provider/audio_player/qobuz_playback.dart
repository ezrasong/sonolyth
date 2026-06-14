import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';

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

    // Flipping the source preference has to take effect on already-played
    // tracks, not just new ones. The source-match cache records which source
    // each track resolved to; clear it and drop the in-memory resolutions so
    // every track re-resolves under the new preference on its next play —
    // migrating the library to Qobuz (or back to YouTube) instead of staying
    // stuck on whatever was cached first.
    final database = ref.read(databaseProvider);
    await database.delete(database.sourceMatchTable).go();
    ref.invalidate(sourcedTrackProvider);
  }
}

final qobuzPlaybackEnabledProvider =
    AsyncNotifierProvider<QobuzPlaybackEnabledNotifier, bool>(
  QobuzPlaybackEnabledNotifier.new,
);
