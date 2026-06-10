part of 'metadata.dart';

@Freezed(genericArgumentFactories: true)
class SonolythPaginationResponseObject<T>
    with _$SonolythPaginationResponseObject<T> {
  factory SonolythPaginationResponseObject({
    required int limit,
    required int? nextOffset,
    required int total,
    required bool hasMore,
    required List<T> items,
  }) = _SonolythPaginationResponseObject<T>;

  factory SonolythPaginationResponseObject.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) =>
      _$SonolythPaginationResponseObjectFromJson<T>(
        json,
        (json) => fromJsonT(json as Map<String, dynamic>),
      );
}
