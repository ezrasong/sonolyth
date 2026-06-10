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
