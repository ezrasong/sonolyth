part of 'metadata.dart';

@freezed
class SonolythSearchResponseObject with _$SonolythSearchResponseObject {
  factory SonolythSearchResponseObject({
    required List<SonolythSimpleAlbumObject> albums,
    required List<SonolythFullArtistObject> artists,
    required List<SonolythSimplePlaylistObject> playlists,
    required List<SonolythFullTrackObject> tracks,
  }) = _SonolythSearchResponseObject;

  factory SonolythSearchResponseObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythSearchResponseObjectFromJson(json);
}
