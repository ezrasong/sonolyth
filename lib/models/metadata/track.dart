part of 'metadata.dart';

@freezed
class SonolythTrackObject with _$SonolythTrackObject {
  factory SonolythTrackObject.local({
    required String id,
    required String name,
    required String externalUri,
    @Default([]) List<SonolythSimpleArtistObject> artists,
    required SonolythSimpleAlbumObject album,
    required int durationMs,
    required String path,
  }) = SonolythLocalTrackObject;

  factory SonolythTrackObject.full({
    required String id,
    required String name,
    required String externalUri,
    @Default([]) List<SonolythSimpleArtistObject> artists,
    required SonolythSimpleAlbumObject album,
    required int durationMs,
    required String isrc,
    required bool explicit,
    // ISO-8601 timestamp of when the track was added to the collection it was
    // fetched from (playlist / liked songs). Null outside those contexts
    // (album tracks, search results) and on providers that don't expose it.
    // Spotify's pathfinder returns this as a nested object ({isoString: ...})
    // rather than a bare string, so it's coerced via [_readAddedAt] — passing
    // the raw Map straight into a `String?` cast crashed every track's parse.
    @JsonKey(fromJson: _readAddedAt) String? addedAt,
  }) = SonolythFullTrackObject;

  factory SonolythTrackObject.localTrackFromFile(
    File file, {
    Metadata? metadata,
    String? art,
  }) {
    return SonolythLocalTrackObject(
      id: file.absolute.path,
      name: metadata?.title ?? basenameWithoutExtension(file.path),
      externalUri: "file://${file.absolute.path}",
      artists: metadata?.artist?.split(",").map((a) {
            return SonolythSimpleArtistObject(
              id: a.trim(),
              name: a.trim(),
              externalUri: "file://${file.absolute.path}",
            );
          }).toList() ??
          [
            SonolythSimpleArtistObject(
              id: "unknown",
              name: "Unknown Artist",
              externalUri: "file://${file.absolute.path}",
            ),
          ],
      album: SonolythSimpleAlbumObject(
        albumType: SonolythAlbumType.album,
        id: metadata?.album ?? "unknown",
        name: metadata?.album ?? "Unknown Album",
        externalUri: "file://${file.absolute.path}",
        artists: [
          SonolythSimpleArtistObject(
            id: metadata?.albumArtist ?? "unknown",
            name: metadata?.albumArtist ?? "Unknown Artist",
            externalUri: "file://${file.absolute.path}",
          ),
        ],
        releaseDate:
            metadata?.year != null ? "${metadata!.year}-01-01" : "1970-01-01",
        images: [
          if (art != null)
            SonolythImageObject(
              url: art,
              width: 300,
              height: 300,
            ),
        ],
      ),
      durationMs: metadata?.durationMs?.toInt() ?? 0,
      path: file.path,
    );
  }

  factory SonolythTrackObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythTrackObjectFromJson(
        json.containsKey("path")
            ? {...json, "runtimeType": "local"}
            : {...json, "runtimeType": "full"},
      );
}

/// Coerces a track's "added at" into an ISO-8601 string. Spotify's pathfinder
/// playlist/library items carry it as an object (e.g. `{isoString: "..."}` or
/// an epoch-millis wrapper), not a bare string — and providers that don't
/// expose it send null. Anything we can't read becomes null so a single odd
/// shape can never crash the whole track-list parse (the date-added sort just
/// no-ops for those tracks).
String? _readAddedAt(Object? value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  if (value is Map) {
    final iso = value["isoString"] ??
        value["iso"] ??
        value["date"] ??
        value["datetime"] ??
        value["dateTime"] ??
        value["timestamp"];
    if (iso is String && iso.isNotEmpty) return iso;
    final millis = value["totalMilliseconds"] ??
        value["milliseconds"] ??
        value["ms"] ??
        value["epochMillis"];
    if (millis is num) {
      return DateTime.fromMillisecondsSinceEpoch(millis.toInt())
          .toUtc()
          .toIso8601String();
    }
    // Diagnostic (one-shot): we got a Map we couldn't read a date out of, so
    // the date-added sort silently no-ops. The `diagnostics` flag is never
    // enabled in shipped builds, so route this through reportError (which does
    // append to .spotube_logs in release) to capture the real field shape once.
    // Remove once the key is confirmed and wired.
    if (!_loggedAddedAtShape) {
      _loggedAddedAtShape = true;
      AppLogger.reportError(
        "ADDEDAT_PROBE keys=${value.keys.toList()} sample=$value",
      );
    }
  }
  return null;
}

bool _loggedAddedAtShape = false;

extension AsMediaListSonolythTrackObject on Iterable<SonolythTrackObject> {
  List<SonolythMedia> asMediaList() {
    return map((track) => SonolythMedia(track)).toList();
  }
}

extension ToMetadataSonolythFullTrackObject on SonolythFullTrackObject {
  Metadata toMetadata({
    required int fileLength,
    Uint8List? imageBytes,
    String? mimeType,
  }) {
    return Metadata(
      title: name,
      artist: artists.map((a) => a.name).join(", "),
      album: album.name,
      albumArtist: artists.map((a) => a.name).join(", "),
      year: album.releaseDate == null
          ? 1970
          : DateTime.tryParse(album.releaseDate!)?.year ??
              int.tryParse(album.releaseDate!) ??
              1970,
      durationMs: durationMs.toDouble(),
      fileSize: BigInt.from(fileLength),
      picture: imageBytes != null
          ? Picture(
              data: imageBytes,
              mimeType: mimeType ??
                  lookupMimeType("", headerBytes: imageBytes) ??
                  "image/jpeg",
            )
          : null,
    );
  }
}
