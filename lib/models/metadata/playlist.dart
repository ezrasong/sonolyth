part of 'metadata.dart';

@freezed
class SonolythFullPlaylistObject with _$SonolythFullPlaylistObject {
  factory SonolythFullPlaylistObject({
    required String id,
    required String name,
    required String description,
    required String externalUri,
    required SonolythUserObject owner,
    @Default([]) List<SonolythImageObject> images,
    @Default([]) List<SonolythUserObject> collaborators,
    @Default(false) bool collaborative,
    @Default(false) bool public,
  }) = _SonolythFullPlaylistObject;

  factory SonolythFullPlaylistObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythFullPlaylistObjectFromJson(json);
}

@freezed
class SonolythSimplePlaylistObject with _$SonolythSimplePlaylistObject {
  factory SonolythSimplePlaylistObject({
    required String id,
    required String name,
    required String description,
    required String externalUri,
    required SonolythUserObject owner,
    @Default([]) List<SonolythImageObject> images,
  }) = _SonolythSimplePlaylistObject;

  factory SonolythSimplePlaylistObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythSimplePlaylistObjectFromJson(json);
}
