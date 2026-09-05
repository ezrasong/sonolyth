import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';

/// What a list row can say about a track's audio format — the "flac | 24 bit"
/// half of Poweramp's `ItemTrackMeta` line ("♪ 3:23 | flac | 24 bit").
class TrackFormat {
  final String container;
  final int? bitDepth;
  final double? sampleRate;

  const TrackFormat({
    required this.container,
    this.bitDepth,
    this.sampleRate,
  });

  factory TrackFormat.fromStream(SonolythAudioSourceStreamObject stream) =>
      TrackFormat(
        container: stream.container,
        bitDepth: stream.bitDepth,
        sampleRate: stream.sampleRate,
      );

  /// From a file on disk (a download or a local track): the extension is all
  /// that is known without opening the file, so bit depth stays unknown.
  static TrackFormat? fromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot >= path.length - 1) return null;
    final ext = path.substring(dot + 1).toLowerCase();
    if (ext.isEmpty || ext.length > 5 || ext.contains('/')) return null;
    return TrackFormat(container: ext);
  }

  /// The `TopMetaInfoLabel` line for this format — the same order and the same
  /// formatter `SourcedTrack.qualityLabel` uses for a resolved stream, so the
  /// player's chip reads identically whether the audio came off the wire or off
  /// the disk. Whatever is unknown is dropped rather than printed as "null" or
  /// guessed: a file read off its extension knows only its container, so most
  /// of the time this is one word.
  String get label => [
        container,
        if (bitDepth != null) "${bitDepth}bit",
        if (sampleRate != null)
          "${oneOptionalDecimalFormatter.format(sampleRate! / 1000)}kHz",
      ].join(" • ");

  @override
  bool operator ==(Object other) =>
      other is TrackFormat &&
      other.container == container &&
      other.bitDepth == bitDepth &&
      other.sampleRate == sampleRate;

  @override
  int get hashCode => Object.hash(container, bitDepth, sampleRate);
}

/// Formats of every stream this session has resolved, by track id.
///
/// A list row must never *cause* a resolve — watching `sourcedTrackProvider`
/// for every visible row would fire a catalogue search per row — so rows read
/// this registry instead, and the resolver publishes into it whenever a track
/// is fetched, refreshed or swapped to a sibling. Tracks that have not been
/// played or prefetched this session simply have no entry and show duration
/// alone, which is honest: nothing knows their format yet.
class TrackFormatRegistryNotifier extends Notifier<Map<String, TrackFormat>> {
  @override
  Map<String, TrackFormat> build() => const {};

  void record(String trackId, TrackFormat format) {
    if (state[trackId] == format) return;
    state = Map.unmodifiable({...state, trackId: format});
  }
}

final trackFormatRegistryProvider =
    NotifierProvider<TrackFormatRegistryNotifier, Map<String, TrackFormat>>(
  TrackFormatRegistryNotifier.new,
);
