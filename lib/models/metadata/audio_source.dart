part of 'metadata.dart';

final oneOptionalDecimalFormatter = NumberFormat('0.#', 'en_US');

enum SonolythMediaCompressionType {
  lossy,
  lossless,
}

@Freezed(unionKey: 'type')
class SonolythAudioSourceContainerPreset
    with _$SonolythAudioSourceContainerPreset {
  const SonolythAudioSourceContainerPreset._();

  @FreezedUnionValue("lossy")
  factory SonolythAudioSourceContainerPreset.lossy({
    required SonolythMediaCompressionType type,
    required String name,
    required List<SonolythAudioLossyContainerQuality> qualities,
  }) = SonolythAudioSourceContainerPresetLossy;

  @FreezedUnionValue("lossless")
  factory SonolythAudioSourceContainerPreset.lossless({
    required SonolythMediaCompressionType type,
    required String name,
    required List<SonolythAudioLosslessContainerQuality> qualities,
  }) = SonolythAudioSourceContainerPresetLossless;

  factory SonolythAudioSourceContainerPreset.fromJson(
          Map<String, dynamic> json) =>
      _$SonolythAudioSourceContainerPresetFromJson(json);

  String getFileExtension() {
    return switch (name) {
      "mp4" => "m4a",
      "webm" => "weba",
      _ => name,
    };
  }
}

@freezed
class SonolythAudioLossyContainerQuality
    with _$SonolythAudioLossyContainerQuality {
  const SonolythAudioLossyContainerQuality._();

  factory SonolythAudioLossyContainerQuality({
    required int bitrate, // bits per second
  }) = _SonolythAudioLossyContainerQuality;

  factory SonolythAudioLossyContainerQuality.fromJson(
          Map<String, dynamic> json) =>
      _$SonolythAudioLossyContainerQualityFromJson(json);

  @override
  toString() {
    return "${oneOptionalDecimalFormatter.format(bitrate / 1000)}kbps";
  }
}

@freezed
class SonolythAudioLosslessContainerQuality
    with _$SonolythAudioLosslessContainerQuality {
  const SonolythAudioLosslessContainerQuality._();

  factory SonolythAudioLosslessContainerQuality({
    required int bitDepth, // bit
    required int sampleRate, // hz
  }) = _SonolythAudioLosslessContainerQuality;

  factory SonolythAudioLosslessContainerQuality.fromJson(
          Map<String, dynamic> json) =>
      _$SonolythAudioLosslessContainerQualityFromJson(json);

  @override
  toString() {
    return "${bitDepth}bit • ${oneOptionalDecimalFormatter.format(sampleRate / 1000)}kHz";
  }
}

@freezed
class SonolythAudioSourceMatchObject with _$SonolythAudioSourceMatchObject {
  factory SonolythAudioSourceMatchObject({
    required String id,
    required String title,
    required List<String> artists,
    required Duration duration,
    String? thumbnail,
    required String externalUri,
  }) = _SonolythAudioSourceMatchObject;

  factory SonolythAudioSourceMatchObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythAudioSourceMatchObjectFromJson(json);
}

@freezed
class SonolythAudioSourceStreamObject with _$SonolythAudioSourceStreamObject {
  factory SonolythAudioSourceStreamObject({
    required String url,
    required String container,
    required SonolythMediaCompressionType type,
    String? codec,
    double? bitrate,
    int? bitDepth,
    double? sampleRate,
  }) = _SonolythAudioSourceStreamObject;

  factory SonolythAudioSourceStreamObject.fromJson(Map<String, dynamic> json) =>
      _$SonolythAudioSourceStreamObjectFromJson(json);
}
