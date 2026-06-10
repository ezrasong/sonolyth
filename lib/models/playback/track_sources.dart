import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sonolyth/models/metadata/metadata.dart';

part 'track_sources.g.dart';

@JsonSerializable()
class BasicSourcedTrack {
  final SonolythFullTrackObject query;
  final SonolythAudioSourceMatchObject info;
  final String source;
  final List<SonolythAudioSourceStreamObject> sources;
  final List<SonolythAudioSourceMatchObject> siblings;
  BasicSourcedTrack({
    required this.query,
    required this.source,
    required this.info,
    required this.sources,
    this.siblings = const [],
  });

  factory BasicSourcedTrack.fromJson(Map<String, dynamic> json) =>
      _$BasicSourcedTrackFromJson(json);
  Map<String, dynamic> toJson() => _$BasicSourcedTrackToJson(this);
}
