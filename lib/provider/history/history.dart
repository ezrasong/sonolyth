import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/database/database.dart';

class PlaybackHistoryActions {
  final Ref ref;
  AppDatabase get _db => ref.read(databaseProvider);

  PlaybackHistoryActions(this.ref);

  Future<void> _batchInsertHistoryEntries(
      List<HistoryTableCompanion> entries) async {
    await _db.batch((batch) {
      batch.insertAll(_db.historyTable, entries);
    });
  }

  Future<void> addPlaylists(List<SonolythSimplePlaylistObject> playlists) async {
    await _batchInsertHistoryEntries([
      for (final playlist in playlists)
        HistoryTableCompanion.insert(
          type: HistoryEntryType.playlist,
          itemId: playlist.id,
          data: playlist.toJson(),
        ),
    ]);
  }

  Future<void> addAlbums(List<SonolythSimpleAlbumObject> albums) async {
    await _batchInsertHistoryEntries([
      for (final albums in albums)
        HistoryTableCompanion.insert(
          type: HistoryEntryType.album,
          itemId: albums.id,
          data: albums.toJson(),
        ),
    ]);
  }

  Future<void> addTracks(List<SonolythTrackObject> tracks) async {
    assert(
      tracks.every((t) => t.artists.every((a) => a.images != null)),
      'Track artists must have images',
    );

    await _batchInsertHistoryEntries([
      for (final track in tracks)
        HistoryTableCompanion.insert(
          type: HistoryEntryType.track,
          itemId: track.id,
          data: track.toJson(),
        ),
    ]);
  }

  Future<void> addTrack(SonolythTrackObject track) async {
    assert(
      track.artists.every((a) => a.images != null),
      'Track artists must have images',
    );

    await _db.into(_db.historyTable).insert(
          HistoryTableCompanion.insert(
            type: HistoryEntryType.track,
            itemId: track.id,
            data: track.toJson(),
          ),
        );
  }

  Future<void> clear() async {
    await _db.delete(_db.historyTable).go();
  }

  /// How many rows the history holds — what Settings puts on the "Clear play
  /// history" row so the action names a number rather than a promise.
  Future<int> count() async {
    final rows = _db.historyTable.id.count();
    return await (_db.selectOnly(_db.historyTable)..addColumns([rows]))
        .map((row) => row.read(rows) ?? 0)
        .getSingle();
  }
}

final playbackHistoryActionsProvider =
    Provider((ref) => PlaybackHistoryActions(ref));
