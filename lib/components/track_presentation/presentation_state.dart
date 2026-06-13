import 'package:collection/collection.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
      presentationTracks: tracks,
      sortBy: SortBy.none,
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
    state = state.copyWith(
      presentationTracks: sortBy == SortBy.none
          ? tracks
          : ServiceUtils.sortTracks(state.presentationTracks, sortBy),
      sortBy: sortBy,
    );
  }
}

final presentationStateProvider = AutoDisposeNotifierProviderFamily<
    PresentationStateNotifier, PresentationState, Object>(
  () => PresentationStateNotifier(),
);
