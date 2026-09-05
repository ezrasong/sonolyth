import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sonolyth/models/lyrics.dart';
import 'package:sonolyth/services/lyrics/flac_vorbis_comments.dart';
import 'package:sonolyth/services/lyrics/lyric_text.dart';

/// Lyrics that travel with the audio file: a `LYRICS`-style Vorbis comment in
/// a FLAC, or an `.lrc` sidecar next to the file. Both are what Poweramp reads
/// for a local track, and both are the user's own data — so they win over any
/// online lookup and are never written to the lyrics cache (the file *is* the
/// cache, and its tags may change under us).
class EmbeddedLyrics {
  EmbeddedLyrics._();

  /// `SubtitleSimple.provider` ids for file-sourced lyrics. Ids, not labels:
  /// the lyrics page maps them to localized text.
  static const providerTags = "file-tags";
  static const providerSidecar = "lrc-file";

  /// Vorbis comment fields taggers use for lyrics, in the order they are
  /// tried. Picard and foobar2000 write `LYRICS`; MusicBee `UNSYNCEDLYRICS`
  /// / `SYNCEDLYRICS`; some older tools spell the pair with a space.
  static const lyricsFields = [
    "LYRICS",
    "UNSYNCEDLYRICS",
    "UNSYNCED LYRICS",
    "SYNCEDLYRICS",
    "SYNCED LYRICS",
  ];

  /// Lyrics for the audio file at [path], or null when it carries none.
  ///
  /// Every candidate — each lyric-bearing tag value, then the sidecar — is
  /// parsed, and the first *synced* one wins; failing that, the first plain
  /// one. Tags are tried before the sidecar only as a tie-break: an `.lrc`
  /// file is by convention timed, so when both exist and both are synced the
  /// tag is what the tagger wrote for this exact file.
  static Future<SubtitleSimple?> forFile(
    String path, {
    required String trackName,
  }) async {
    final candidates = <({ParsedLyricText parsed, String provider, Uri uri})>[];
    // Absolute, like `localTrackFromFile`: a `file:` URI to a relative path
    // is meaningless once the working directory is not what it was.
    final fileUri = Uri.file(File(path).absolute.path);

    final comments = await readFlacVorbisComments(path);
    if (comments != null) {
      for (final field in lyricsFields) {
        for (final value in comments.values(field)) {
          final parsed = parseLyricText(value);
          if (parsed.isEmpty) continue;
          candidates.add(
            (parsed: parsed, provider: providerTags, uri: fileUri),
          );
        }
      }
    }

    final sidecar = await _readSidecar(path);
    if (sidecar != null) {
      final parsed = parseLyricText(sidecar.text);
      if (!parsed.isEmpty) {
        candidates.add((
          parsed: parsed,
          provider: providerSidecar,
          uri: Uri.file(File(sidecar.path).absolute.path),
        ));
      }
    }

    if (candidates.isEmpty) return null;
    final best = candidates.firstWhere(
      (candidate) => candidate.parsed.synced,
      orElse: () => candidates.first,
    );
    return SubtitleSimple(
      uri: best.uri,
      name: trackName,
      lyrics: best.parsed.lines,
      rating: best.parsed.synced ? 100 : 0,
      provider: best.provider,
    );
  }

  /// `<same basename>.lrc` beside the audio file. Three spellings are tried
  /// because Android's storage is case-sensitive and Windows taggers are not
  /// consistent about the extension.
  static Future<({String path, String text})?> _readSidecar(
    String audioPath,
  ) async {
    final base = p.withoutExtension(audioPath);
    for (final extension in const [".lrc", ".LRC", ".Lrc"]) {
      final file = File("$base$extension");
      try {
        if (!await file.exists()) continue;
        return (path: file.path, text: _decodeText(await file.readAsBytes()));
      } on FileSystemException {
        continue;
      }
    }
    return null;
  }

  /// UTF-8 by default; honours a UTF-16 BOM, which Windows lyric editors
  /// still produce, and strips a UTF-8 one.
  static String _decodeText(Uint8List bytes) {
    if (bytes.length >= 2) {
      final bom = (bytes[0] << 8) | bytes[1];
      if (bom == 0xFFFE || bom == 0xFEFF) {
        final endian = bom == 0xFFFE ? Endian.little : Endian.big;
        final data = ByteData.sublistView(bytes, 2);
        final units = Uint16List(data.lengthInBytes ~/ 2);
        for (var i = 0; i < units.length; i++) {
          units[i] = data.getUint16(i * 2, endian);
        }
        return String.fromCharCodes(units);
      }
    }
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith("\uFEFF")) text = text.substring(1);
    return text;
  }
}
