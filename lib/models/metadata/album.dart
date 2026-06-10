part of 'metadata.dart';

enum SonolythAlbumType {
  album,
  single,
  compilation,
}

@freezed
class SonolythFullAlbumObject with _$SonolythFullAlbumObject {
  factory SonolythFullAlbumObject({
    required String id,
    required String name,
    required List<SonolythSimpleArtistObject> artists,
    @Default([]) List<SonolythImageObject> images,
    required String releaseDate,
    required String externalUri,
    required int totalTracks,
    required SonolythAlbumType albumType,
    String? recordLabel,
    List<String>? genres,
  }) = _SonolythFullAlbumObject;

  factory SonolythFullAlbumObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythFullAlbumObjectFromJson(json);
}

@freezed
class SonolythSimpleAlbumObject with _$SonolythSimpleAlbumObject {
  factory SonolythSimpleAlbumObject({
    required String id,
    required String name,
    required String externalUri,
    required List<SonolythSimpleArtistObject> artists,
    @Default([]) List<SonolythImageObject> images,
    required SonolythAlbumType albumType,
    String? releaseDate,
  }) = _SonolythSimpleAlbumObject;

  factory SonolythSimpleAlbumObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythSimpleAlbumObjectFromJson(json);
}
