part of 'metadata.dart';

@freezed
class SonolythUserObject with _$SonolythUserObject {
  factory SonolythUserObject({
    required final String id,
    required final String name,
    @Default([]) final List<SonolythImageObject> images,
    required final String externalUri,
  }) = _SonolythUserObject;

  factory SonolythUserObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythUserObjectFromJson(json);
}
