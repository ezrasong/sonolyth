import 'package:sonolyth/models/metadata/metadata.dart';

class TrackNotFoundError extends Error {
  final SonolythTrackObject track;

  TrackNotFoundError(this.track);

  @override
  String toString() {
    return '[TrackNotFoundError] ${track.name} - ${track.artists.join(", ")}';
  }
}
