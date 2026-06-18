import 'package:collection/collection.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/pages/library/user_local_tracks/user_local_tracks.dart';
import 'package:sonolyth/provider/metadata_plugin/library/tracks.dart';
import 'package:sonolyth/provider/metadata_plugin/tracks/album.dart';
import 'package:sonolyth/provider/metadata_plugin/tracks/playlist.dart';
import 'package:sonolyth/utils/service_utils.dart';

class PresentationState {
  final List<SonolythTrackObject> selectedTracks;
  final List<SonolythTrackObject> presentationTracks;
  final SortBy sortBy;

  const PresentationState({
    required this.selectedTracks,
    required this.presentationTracks,
    required this.sortBy,
  });

  PresentationState copyWith({
    List<SonolythTrackObject>? selectedTracks,
    List<SonolythTrackObject>? presentationTracks,
    SortBy? sortBy,
  }) {
    return PresentationState(
      selectedTracks: selectedTracks ?? this.selectedTracks,
      presentationTracks: presentationTracks ?? this.presentationTracks,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class PresentationStateNotifier
    extends AutoDisposeFamilyNotifier<PresentationState, Object> {
  @override
  PresentationState build(collection) {
    // Apply (and re-apply once it loads from prefs / the user changes it) the
    // sort the user last picked, instead of always starting unsorted.
    final savedSort = ref.watch(playlistSortProvider);
    if (arg case SonolythSimplePlaylistObject() || SonolythSimpleAlbumObject()) {
      if (isSavedTrackPlaylist) {
        ref.listen(
          metadataPluginSavedTracksProvider,
          (previous, next) {
            next.whenData((value) {
              state = state.copyWith(
                presentationTracks: ServiceUtils.sortTracks(
                  value.items,
                  state.sortBy,
                ),
              );
            });
          },
        );
      } else {
        ref.listen(
          arg is SonolythSimplePlaylistObject
              ? metadataPluginPlaylistTracksProvider(
                  (arg as SonolythSimplePlaylistObject).id)
              : metadataPluginAlbumTracksProvider(
                  (arg as SonolythSimpleAlbumObject).id),
          (previous, next) {
            next.whenData((value) {
              state = state.copyWith(
                presentationTracks: ServiceUtils.sortTracks(
                  value.items,
                  state.sortBy,
                ),
              );
            });
          },
        );
      }
    }

    return PresentationState(
      selectedTracks: [],
      presentationTracks: ServiceUtils.sortTracks(tracks, savedSort),
      sortBy: savedSort,
    );
  }

  bool get isSavedTrackPlaylist =>
      arg is SonolythSimplePlaylistObject &&
      (arg as SonolythSimplePlaylistObject).id == "user-liked-tracks";

  List<SonolythTrackObject> get tracks {
    assert(
      arg is SonolythSimplePlaylistObject || arg is SonolythSimpleAlbumObject,
      "arg must be SonolythSimplePlaylistObject or SonolythSimpleAlbumObject",
    );

    final isPlaylist = arg is SonolythSimplePlaylistObject;

    final tracks = switch ((isPlaylist, isSavedTrackPlaylist)) {
          (true, true) =>
            ref.read(metadataPluginSavedTracksProvider).asData?.value.items,
          (true, false) => ref
              .read(metadataPluginPlaylistTracksProvider(
                  (arg as SonolythSimplePlaylistObject).id))
              .asData
              ?.value
              .items,
          _ => ref
              .read(metadataPluginAlbumTracksProvider(
                  (arg as SonolythSimpleAlbumObject).id))
              .asData
              ?.value
              .items,
        } ??
        <SonolythFullTrackObject>[];

    return tracks;
  }

  void selectTrack(SonolythTrackObject track) {
    if (state.selectedTracks.any((e) => e.id == track.id)) {
      return;
    }

    state = state.copyWith(
      selectedTracks: [...state.selectedTracks, track],
    );
  }

  void selectAllTracks() {
    state = state.copyWith(
      selectedTracks: tracks,
    );
  }

  void deselectTrack(SonolythTrackObject track) {
    state = state.copyWith(
      selectedTracks: state.selectedTracks.where((e) => e != track).toList(),
    );
  }

  void deselectAllTracks() {
    state = state.copyWith(
      selectedTracks: [],
    );
  }

  /// Optimistically drop a track from the visible list (and any selection) so a
  /// swipe-to-remove updates instantly; the backing playlist provider is
  /// invalidated separately and reconciles this on its next emit.
  void removeTrack(SonolythTrackObject track) {
    state = state.copyWith(
      presentationTracks:
          state.presentationTracks.where((e) => e.id != track.id).toList(),
      selectedTracks:
          state.selectedTracks.where((e) => e.id != track.id).toList(),
    );
  }

  void filterTracks(String query) {
    if (query.isEmpty) {
      return;
    }

    state = state.copyWith(
      presentationTracks: ServiceUtils.sortTracks(
        tracks
            .map((e) => (weightedRatio(e.name, query), e))
            .sorted((a, b) => b.$1.compareTo(a.$1))
            .where((e) => e.$1 > 50)
            .map((e) => e.$2)
            .toList(),
        state.sortBy,
      ),
    );
  }

  void clearFilter() {
    state = state.copyWith(
      presentationTracks: ServiceUtils.sortTracks(tracks, state.sortBy),
    );
  }

  void sortTracks(SortBy sortBy) {
    // Persist the choice (and re-sort): build() watches playlistSortProvider,
    // so this both remembers the sort for next time and re-applies it here.
    ref.read(playlistSortProvider.notifier).set(sortBy);
  }
}

final presentationStateProvider = AutoDisposeNotifierProviderFamily<
    PresentationStateNotifier, PresentationState, Object>(
  () => PresentationStateNotifier(),
);

/// The last sort the user picked, persisted across playlists and app restarts.
/// Stored in SharedPreferences (no drift migration). Loads asynchronously, so a
/// presentation that watches this re-applies the saved sort once it lands.
class PlaylistSortNotifier extends Notifier<SortBy> {
  static const _prefsKey = "playlist-sort-by";

  @override
  SortBy build() {
    _load();
    return SortBy.none;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_prefsKey);
      if (name == null) return;
      final saved = SortBy.values.firstWhereOrNull((s) => s.name == name);
      if (saved != null && saved != state) state = saved;
    } catch (_) {
      // A missing/unreadable preference just leaves the default (none).
    }
  }

  Future<void> set(SortBy sortBy) async {
    state = sortBy;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, sortBy.name);
    } catch (_) {/* best effort */}
  }
}

final playlistSortProvider =
    NotifierProvider<PlaylistSortNotifier, SortBy>(PlaylistSortNotifier.new);
