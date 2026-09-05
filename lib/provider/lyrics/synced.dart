import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lrc/lrc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/models/lyrics.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/provider/downloaded_tracks_provider.dart';
import 'package:sonolyth/services/dio/dio.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/lyrics/embedded_lyrics.dart';

class SyncedLyricsNotifier
    extends FamilyAsyncNotifier<SubtitleSimple, SonolythTrackObject?> {
  SonolythTrackObject get _track => arg!;

  /// Lyrics credits: [lrclib.net](https://lrclib.net) and their contributors
  /// Thanks for their generous public API
  Future<SubtitleSimple> getLRCLibLyrics() async {
    final packageInfo = await PackageInfo.fromPlatform();

    final res = await globalDio.getUri(
      Uri(
        scheme: "https",
        host: "lrclib.net",
        path: "/api/get",
        queryParameters: {
          "artist_name": _track.artists.first.name,
          "track_name": _track.name,
          "album_name": _track.album.name,
          if (_track.durationMs > 0)
            "duration": (_track.durationMs / 1000).toInt().toString(),
        },
      ),
      options: Options(
        headers: {
          "User-Agent":
              "Sonolyth v${packageInfo.version} (https://github.com/ezrasong/sonolyth)"
        },
        responseType: ResponseType.json,
      ),
    );

    if (res.statusCode != 200) {
      return SubtitleSimple(
        lyrics: [],
        name: _track.name,
        uri: res.realUri,
        rating: 0,
        provider: "LRCLib",
      );
    }

    final json = res.data as Map<String, dynamic>;

    final syncedLyricsRaw = json["syncedLyrics"] as String?;
    final syncedLyrics = syncedLyricsRaw?.isNotEmpty == true
        ? Lrc.parse(syncedLyricsRaw!)
            .lyrics
            .map(LyricSlice.fromLrcLine)
            .toList()
        : null;

    if (syncedLyrics?.isNotEmpty == true) {
      return SubtitleSimple(
        lyrics: syncedLyrics!,
        name: _track.name,
        uri: res.realUri,
        rating: 100,
        provider: "LRCLib",
      );
    }

    final plainLyrics = (json["plainLyrics"] as String)
        .split("\n")
        .map((line) => LyricSlice(text: line, time: Duration.zero))
        .toList();

    return SubtitleSimple(
      lyrics: plainLyrics,
      name: _track.name,
      uri: res.realUri,
      rating: 0,
      provider: "LRCLib",
    );
  }

  /// The audio file playback would read for [track], if any: a local library
  /// track carries its path; a streamed track that has been downloaded is in
  /// the registry. Watching the registry entry re-runs the lookup when a
  /// download lands or is removed while the lyrics page is open.
  Future<String?> _backingFile(SonolythTrackObject track) async {
    if (track is SonolythLocalTrackObject) return track.path;
    ref.watch(downloadedTracksProvider.select((paths) => paths[track.id]));
    final downloads = ref.read(downloadedTracksProvider.notifier);
    // Cold start: the registry is read asynchronously, and deciding before it
    // lands would send a downloaded track to LRCLib.
    await downloads.ready;
    return downloads.pathFor(track.id);
  }

  @override
  FutureOr<SubtitleSimple> build(track) async {
    try {
      final database = ref.watch(databaseProvider);

      if (track == null) {
        throw "No track currently";
      }

      // The file wins: lyrics the user tagged into a local track or dropped
      // beside it as an .lrc are theirs. They are not written to the cache —
      // the file is the cache, and its tags may change under us.
      final filePath = await _backingFile(track);
      if (filePath != null) {
        final embedded = await EmbeddedLyrics.forFile(
          filePath,
          trackName: track.name,
        );
        if (embedded != null) return embedded;
      }

      final cachedLyrics = await (database.select(database.lyricsTable)
            ..where((tbl) => tbl.trackId.equals(track.id)))
          .map((row) => row.data)
          .getSingleOrNull();

      SubtitleSimple? lyrics = cachedLyrics;

      if (lyrics == null ||
          lyrics.lyrics.isEmpty ||
          lyrics.lyrics.length <= 5) {
        lyrics = await getLRCLibLyrics();
      }

      if (lyrics.lyrics.isEmpty) {
        throw Exception("Unable to find lyrics");
      }

      if (cachedLyrics == null || cachedLyrics.lyrics.isEmpty) {
        await database.into(database.lyricsTable).insert(
              LyricsTableCompanion.insert(
                trackId: track.id,
                data: lyrics,
              ),
              mode: InsertMode.replace,
            );
      }

      return lyrics;
    } catch (e, stackTrace) {
      AppLogger.reportError(e, stackTrace);
      rethrow;
    }
  }
}

final syncedLyricsDelayProvider = StateProvider<int>((ref) => 0);

final syncedLyricsProvider = AsyncNotifierProviderFamily<SyncedLyricsNotifier,
    SubtitleSimple, SonolythTrackObject?>(
  () => SyncedLyricsNotifier(),
);

final syncedLyricsMapProvider =
    FutureProvider.family((ref, SonolythTrackObject? track) async {
  final syncedLyrics = await ref.watch(syncedLyricsProvider(track).future);

  final isStaticLyrics =
      syncedLyrics.lyrics.every((l) => l.time == Duration.zero);

  final lyricsMap = syncedLyrics.lyrics
      .map((lyric) => {lyric.time.inSeconds: lyric.text})
      .reduce((accumulator, lyricSlice) => {...accumulator, ...lyricSlice});

  return (static: isStaticLyrics, lyricsMap: lyricsMap);
});
