import 'package:sonolyth/models/lyrics.dart';

/// Free-form lyric text, parsed into slices the lyrics pages can show.
class ParsedLyricText {
  const ParsedLyricText({required this.lines, required this.synced});

  final List<LyricSlice> lines;

  /// True when the text carried LRC line timestamps; false when it is plain
  /// text, in which case every slice sits at [Duration.zero] and the synced
  /// page hands over to the plain one (its existing `static` rule).
  final bool synced;

  /// Nothing worth showing — no lines, or only blank ones.
  bool get isEmpty => lines.every((line) => line.text.isEmpty);
}

// `[mm:ss.xx]`, but tolerant of what taggers actually write: `[m:ss]`,
// `[mm:ss.xxx]`, `[mm:ss:xx]`, and several stamps on one repeated line.
final _timestamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _leadingTimestamps = RegExp(
  r'^\s*((?:\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\]\s*)+)(.*)$',
);
// `[ar:…]`, `[ti:…]`, `[offset:…]`, `[tool:…]` — header tags, not lyrics.
final _metadataTag = RegExp(r'^\s*\[[A-Za-z_][A-Za-z0-9_]*:[^\]]*\]\s*$');
// Enhanced-LRC word stamps inside a line: `<00:12.34>word`.
final _wordTimestamp = RegExp(r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>\s?');

/// Parses LRC or plain lyric text.
///
/// The `lrc` package's parser is used for LRCLib, whose output is canonical.
/// Text that arrives inside a tag or an `.lrc` file is not: three-digit
/// milliseconds, missing fractions, unknown header tags and stray untimed
/// lines are all common, and the package rejects the whole text for any one of
/// them. This parser keeps what it can. The text counts as synced when the
/// timed lines are not outnumbered by untimed ones — a single `[verse 1]`
/// style bracket in an otherwise plain lyric must not turn it into a
/// three-line "synced" song.
ParsedLyricText parseLyricText(String text) {
  final rawLines =
      text.replaceAll("\r\n", "\n").replaceAll("\r", "\n").split("\n");

  // (time, text, order): time is null for an untimed line.
  final entries = <({Duration? time, String text, int order})>[];
  var timedCount = 0;
  var untimedCount = 0;

  for (final rawLine in rawLines) {
    final line = rawLine.trim();
    if (_metadataTag.hasMatch(line)) continue;

    final match = _leadingTimestamps.firstMatch(line);
    if (match == null) {
      if (line.isNotEmpty) untimedCount++;
      entries.add((time: null, text: line, order: entries.length));
      continue;
    }

    final content = match.group(2)!.replaceAll(_wordTimestamp, "").trim();
    for (final stamp in _timestamp.allMatches(match.group(1)!)) {
      timedCount++;
      entries.add((
        time: _durationOf(stamp),
        text: content,
        order: entries.length,
      ));
    }
  }

  final synced = timedCount > 0 && timedCount >= untimedCount;
  if (synced) {
    final timed = entries.where((e) => e.time != null).toList()
      // `List.sort` is not stable; the order tie-break keeps two lines that
      // share a stamp in file order.
      ..sort((a, b) {
        final byTime = a.time!.compareTo(b.time!);
        return byTime != 0 ? byTime : a.order.compareTo(b.order);
      });
    return ParsedLyricText(
      lines: [for (final e in timed) LyricSlice(time: e.time!, text: e.text)],
      synced: true,
    );
  }

  // Plain: keep interior blank lines (stanza breaks), drop the outer ones.
  final plain = entries.map((e) => e.text).toList();
  while (plain.isNotEmpty && plain.first.isEmpty) {
    plain.removeAt(0);
  }
  while (plain.isNotEmpty && plain.last.isEmpty) {
    plain.removeLast();
  }
  return ParsedLyricText(
    lines: [
      for (final line in plain) LyricSlice(time: Duration.zero, text: line),
    ],
    synced: false,
  );
}

Duration _durationOf(RegExpMatch stamp) {
  final minutes = int.parse(stamp.group(1)!);
  final seconds = int.parse(stamp.group(2)!);
  final fraction = stamp.group(3);
  var milliseconds = 0;
  if (fraction != null) {
    // One digit is tenths, two hundredths, three milliseconds.
    milliseconds = int.parse(fraction) * (fraction.length == 1
        ? 100
        : fraction.length == 2
            ? 10
            : 1);
  }
  return Duration(
    minutes: minutes,
    seconds: seconds,
    milliseconds: milliseconds,
  );
}
