part of 'metadata.dart';

@freezed
class SonolythFullArtistObject with _$SonolythFullArtistObject {
  factory SonolythFullArtistObject({
    required String id,
    required String name,
    required String externalUri,
    @Default([]) List<SonolythImageObject> images,
    List<String>? genres,
    int? followers,
  }) = _SonolythFullArtistObject;

  factory SonolythFullArtistObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythFullArtistObjectFromJson(json);
}

@freezed
class SonolythSimpleArtistObject with _$SonolythSimpleArtistObject {
  factory SonolythSimpleArtistObject({
    required String id,
    required String name,
    required String externalUri,
    List<SonolythImageObject>? images,
  }) = _SonolythSimpleArtistObject;

  factory SonolythSimpleArtistObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythSimpleArtistObjectFromJson(json);
}

extension SonolythFullArtistObjectAsString on List<SonolythFullArtistObject> {
  String asString() {
    return map((e) => e.name).join(", ");
  }
}

extension SonolythSimpleArtistObjectAsString on List<SonolythSimpleArtistObject> {
  String asString() {
    return map((e) => e.name).join(", ");
  }
}
