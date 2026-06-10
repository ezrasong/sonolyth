part of 'metadata.dart';

@Freezed(genericArgumentFactories: true)
class SonolythBrowseSectionObject<T> with _$SonolythBrowseSectionObject<T> {
  factory SonolythBrowseSectionObject({
    required String id,
    required String title,
    required String externalUri,
    required bool browseMore,
    required List<T> items,
  }) = _SonolythBrowseSectionObject<T>;

  factory SonolythBrowseSectionObject.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) =>
      _$SonolythBrowseSectionObjectFromJson<T>(
        json,
        (json) => fromJsonT(json as Map<String, dynamic>),
      );
}
