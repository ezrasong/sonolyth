import 'package:sonolyth/models/metadata/metadata.dart';

/// Encryption scheme applied to a resolved download stream, if any.
enum SpotiFlacEncryption {
  none,

  /// Deezer CDN streams: Blowfish-CBC on every third 2048-byte chunk.
  deezerBlowfish,
}

/// A resolved, downloadable lossless stream for a track.
class SpotiFlacDownloadResolution {
  final String url;

  /// Lowercase file extension without the dot, e.g. "flac".
  final String fileExtension;
  final SpotiFlacEncryption encryption;

  /// Provider-specific id needed to derive the decryption key
  /// (the Deezer track id for [SpotiFlacEncryption.deezerBlowfish]).
  final String? decryptionSeed;

  const SpotiFlacDownloadResolution({
    required this.url,
    this.fileExtension = "flac",
    this.encryption = SpotiFlacEncryption.none,
    this.decryptionSeed,
  });
}

/// A lossless download source backed by the zarz gateway, ported from the
/// SpotiFLAC Mobile `.spotiflac-ext` extensions so downloads happen entirely
/// in-app instead of being handed off to the external SpotiFLAC app.
abstract class SpotiFlacProvider {
  /// Stable id used for ordering/enabling in preferences (e.g. "qobuz").
  String get id;

  /// Human-facing name shown in settings.
  String get displayName;

  /// Quality option ids this provider accepts, best-first.
  List<String> get qualities;

  String get defaultQuality;

  /// Resolves [track] to a direct, downloadable lossless URL, or null when the
  /// provider has no match. Implementations match by ISRC first, then fall
  /// back to a title + artist search.
  Future<SpotiFlacDownloadResolution?> resolve(
    SonolythFullTrackObject track,
    String quality,
  );
}
