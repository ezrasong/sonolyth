import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';

/// Opt-in toggle for resolving playback through the native Tidal audio source
/// (ISRC-exact, lossless) as a fallback between Qobuz and the YouTube plugin.
/// Tracks Qobuz doesn't carry try Tidal next; anything neither has falls back
/// to YouTube.
///
/// Stored in SharedPreferences (no DB drift migration). Defaults to off.
const _prefsKey = "tidal-playback-enabled";

class TidalPlaybackEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_prefsKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_prefsKey, enabled);
    state = AsyncData(enabled);

    // Like the Qobuz toggle: changing the source preference must re-resolve
    // already-played tracks, not just new ones. Clear the source-match cache
    // and drop in-memory resolutions so each track re-resolves under the new
    // Qobuz -> Tidal -> YouTube order on its next play.
    final database = ref.read(databaseProvider);
    await database.delete(database.sourceMatchTable).go();
    ref.invalidate(sourcedTrackProvider);
  }
}

final tidalPlaybackEnabledProvider =
    AsyncNotifierProvider<TidalPlaybackEnabledNotifier, bool>(
  TidalPlaybackEnabledNotifier.new,
);
