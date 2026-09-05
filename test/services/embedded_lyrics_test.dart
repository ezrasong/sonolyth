import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sonolyth/services/lyrics/embedded_lyrics.dart';
import 'package:sonolyth/services/lyrics/flac_vorbis_comments.dart';
import 'package:sonolyth/services/lyrics/lyric_text.dart';

Uint8List _u32le(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

/// Body of a VORBIS_COMMENT block, as the spec lays it out.
Uint8List vorbisCommentBody(String vendor, List<String> entries) {
  final out = BytesBuilder();
  final vendorBytes = utf8.encode(vendor);
  out.add(_u32le(vendorBytes.length));
  out.add(vendorBytes);
  out.add(_u32le(entries.length));
  for (final entry in entries) {
    final bytes = utf8.encode(entry);
    out.add(_u32le(bytes.length));
    out.add(bytes);
  }
  return out.toBytes();
}

const typeStreamInfo = 0;
const typePadding = 1;
const typeVorbisComment = 4;
const typePicture = 6;

/// A FLAC file: marker, the given (type, body) metadata blocks with the last
/// one flagged, then a fake frame sync so there is "audio" after the headers.
Uint8List flacBytes(List<(int, Uint8List)> blocks, {bool id3Prefix = false}) {
  final out = BytesBuilder();
  if (id3Prefix) {
    // ID3v2.3 header: "ID3", version 3.0, no flags, syncsafe size 20.
    out.add([0x49, 0x44, 0x33, 3, 0, 0, 0, 0, 0, 20]);
    out.add(Uint8List(20));
  }
  out.add(utf8.encode("fLaC"));
  for (var i = 0; i < blocks.length; i++) {
    final (type, body) = blocks[i];
    final isLast = i == blocks.length - 1;
    out.addByte((isLast ? 0x80 : 0) | type);
    out.add([
      (body.length >> 16) & 0xFF,
      (body.length >> 8) & 0xFF,
      body.length & 0xFF,
    ]);
    out.add(body);
  }
  out.add([0xFF, 0xF8, 0x00, 0x00]);
  return out.toBytes();
}

final streamInfo = (typeStreamInfo, Uint8List(34));
// Big enough that reading it instead of seeking past it would be noticeable.
final picture = (typePicture, Uint8List(200 * 1024));

final fixturePath = p.join("test", "fixtures", "lyrics_tagged.flac");

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp("embedded_lyrics_test");
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Future<File> write(String name, List<int> bytes) async {
    final file = File(p.join(tmp.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  group("parseVorbisCommentBlock", () {
    test("reads vendor and fields, keyed case-insensitively", () {
      final comments = parseVorbisCommentBlock(
        vorbisCommentBody("vendor x", ["Title=Song", "artist=Someone"]),
      );
      expect(comments.vendor, "vendor x");
      expect(comments.first("TITLE"), "Song");
      expect(comments.first("title"), "Song");
      expect(comments.first("Artist"), "Someone");
      expect(comments.keys, containsAll(["TITLE", "ARTIST"]));
    });

    test("keeps every value of a repeated field, in order", () {
      final comments = parseVorbisCommentBlock(
        vorbisCommentBody("v", ["ARTIST=A", "ARTIST=B", "ALBUM=X"]),
      );
      expect(comments.values("artist"), ["A", "B"]);
    });

    test("skips entries with no '=' or an empty key", () {
      final comments = parseVorbisCommentBlock(
        vorbisCommentBody("v", ["garbage", "=novalue", "OK=yes"]),
      );
      expect(comments.keys, ["OK"]);
    });

    test("a truncated block yields the fields that were intact", () {
      final full = vorbisCommentBody("v", ["A=1", "B=2", "C=3"]);
      final truncated = Uint8List.sublistView(full, 0, full.length - 3);
      final comments = parseVorbisCommentBlock(truncated);
      expect(comments.first("A"), "1");
      expect(comments.first("B"), "2");
      expect(comments.first("C"), isNull);
    });

    test("an empty body is empty, not an error", () {
      expect(parseVorbisCommentBlock(Uint8List(0)).isEmpty, isTrue);
      expect(parseVorbisCommentBlock(Uint8List(3)).isEmpty, isTrue);
    });
  });

  group("readFlacVorbisComments", () {
    test("finds the comment block behind STREAMINFO and a large PICTURE",
        () async {
      final file = await write(
        "a.flac",
        flacBytes([
          streamInfo,
          picture,
          (typeVorbisComment, vorbisCommentBody("v", ["LYRICS=la la"])),
        ]),
      );
      final comments = await readFlacVorbisComments(file.path);
      expect(comments?.first("LYRICS"), "la la");
    });

    test("skips a leading ID3v2 tag", () async {
      final file = await write(
        "id3.flac",
        flacBytes(
          [
            streamInfo,
            (typeVorbisComment, vorbisCommentBody("v", ["LYRICS=x"])),
            (typePadding, Uint8List(64)),
          ],
          id3Prefix: true,
        ),
      );
      expect((await readFlacVorbisComments(file.path))?.first("LYRICS"), "x");
    });

    test("returns null when there is no comment block", () async {
      final file = await write(
        "none.flac",
        flacBytes([streamInfo, (typePadding, Uint8List(16))]),
      );
      expect(await readFlacVorbisComments(file.path), isNull);
    });

    test("returns null for a non-FLAC file, a missing file, and an empty one",
        () async {
      final riff = await write("a.wav", utf8.encode("RIFF....WAVEfmt "));
      final empty = await write("empty.flac", const []);
      expect(await readFlacVorbisComments(riff.path), isNull);
      expect(await readFlacVorbisComments(empty.path), isNull);
      expect(
        await readFlacVorbisComments(p.join(tmp.path, "missing.flac")),
        isNull,
      );
    });

    test("a file cut off inside the comment block still yields early fields",
        () async {
      final whole = flacBytes([
        streamInfo,
        (typeVorbisComment, vorbisCommentBody("v", ["A=1", "LYRICS=long"])),
      ]);
      // Drop the fake frame plus the tail of the last entry.
      final cut = await write(
        "cut.flac",
        Uint8List.sublistView(whole, 0, whole.length - 4 - 6),
      );
      final comments = await readFlacVorbisComments(cut.path);
      expect(comments?.first("A"), "1");
      expect(comments?.first("LYRICS"), isNull);
    });

    test("reads the ffmpeg-tagged fixture", () async {
      final comments = await readFlacVorbisComments(fixturePath);
      expect(comments, isNotNull);
      expect(comments!.first("ARTIST"), "Fixture Artist");
      expect(comments.first("TITLE"), "Tagged Fixture");
      expect(comments.first("LYRICS"), contains("[00:02.500]Second line"));
    });
  });

  group("parseLyricText", () {
    test("two-digit, three-digit and missing fractions all time correctly",
        () {
      final parsed = parseLyricText(
        "[00:01.50]a\n[00:02.500]b\n[00:03]c\n[0:04.5]d\n[00:05:25]e",
      );
      expect(parsed.synced, isTrue);
      expect(
        parsed.lines.map((l) => l.time.inMilliseconds),
        [1500, 2500, 3000, 4500, 5250],
      );
      expect(parsed.lines.map((l) => l.text), ["a", "b", "c", "d", "e"]);
    });

    test("a line with several stamps repeats at each, sorted by time", () {
      final parsed = parseLyricText("[00:10.00][00:02.00]chorus\n[00:05.00]v");
      expect(
        parsed.lines.map((l) => "${l.time.inSeconds}:${l.text}"),
        ["2:chorus", "5:v", "10:chorus"],
      );
    });

    test("header tags are dropped and enhanced word stamps stripped", () {
      final parsed = parseLyricText(
        "[ar:Artist]\n[ti:Title]\n[offset:+200]\n[tool:Whatever]\n"
        "[00:01.00]<00:01.00>hello <00:01.50>world\n[00:02.00]bye",
      );
      expect(parsed.synced, isTrue);
      expect(parsed.lines.map((l) => l.text), ["hello world", "bye"]);
    });

    test("lines sharing a stamp keep file order", () {
      final parsed = parseLyricText("[00:01.00]first\n[00:01.00]second");
      expect(parsed.lines.map((l) => l.text), ["first", "second"]);
    });

    test("plain text stays plain, keeps stanza breaks, trims the outer blanks",
        () {
      final parsed = parseLyricText("\n\nline one\nline two\n\nline three\n\n");
      expect(parsed.synced, isFalse);
      expect(
        parsed.lines.map((l) => l.text),
        ["line one", "line two", "", "line three"],
      );
      expect(parsed.lines.every((l) => l.time == Duration.zero), isTrue);
    });

    test("one stray stamp in an otherwise plain lyric does not make it synced",
        () {
      final parsed = parseLyricText("[01:00]\nverse\nverse\nverse");
      expect(parsed.synced, isFalse);
      // The stamp-only line is blank once its bracket goes, and a leading
      // blank is trimmed like any other.
      expect(parsed.lines.map((l) => l.text), ["verse", "verse", "verse"]);
    });

    test("CRLF and lone CR line endings are accepted", () {
      final parsed = parseLyricText("[00:01.00]a\r\n[00:02.00]b\r[00:03.00]c");
      expect(parsed.lines.map((l) => l.text), ["a", "b", "c"]);
    });

    test("whitespace-only text is empty", () {
      expect(parseLyricText("  \n\n \t").isEmpty, isTrue);
      expect(parseLyricText("").isEmpty, isTrue);
    });
  });

  group("EmbeddedLyrics.forFile", () {
    const synced = "[00:01.00]one\n[00:02.00]two";
    const plain = "just words\nmore words";

    test("reads synced lyrics out of the fixture's LYRICS tag", () async {
      final lyrics = await EmbeddedLyrics.forFile(
        fixturePath,
        trackName: "Tagged Fixture",
      );
      expect(lyrics, isNotNull);
      expect(lyrics!.provider, EmbeddedLyrics.providerTags);
      expect(lyrics.rating, 100);
      expect(lyrics.name, "Tagged Fixture");
      expect(lyrics.lyrics.map((l) => l.text),
          ["First line", "Second line", "Third line"]);
      expect(lyrics.lyrics.first.time, const Duration(seconds: 1));
      expect(lyrics.lyrics[1].time, const Duration(milliseconds: 2500));
      expect(lyrics.uri.toFilePath(), p.absolute(fixturePath));
    });

    test("a synced sidecar beats a plain tag", () async {
      final flac = await write(
        "t.flac",
        flacBytes([
          streamInfo,
          (typeVorbisComment, vorbisCommentBody("v", ["LYRICS=$plain"])),
        ]),
      );
      await write("t.lrc", utf8.encode(synced));
      final lyrics = await EmbeddedLyrics.forFile(flac.path, trackName: "t");
      expect(lyrics?.provider, EmbeddedLyrics.providerSidecar);
      expect(lyrics?.lyrics.map((l) => l.text), ["one", "two"]);
    });

    test("when both are synced the tag wins", () async {
      final flac = await write(
        "u.flac",
        flacBytes([
          streamInfo,
          (typeVorbisComment, vorbisCommentBody("v", ["LYRICS=$synced"])),
        ]),
      );
      await write("u.lrc", utf8.encode("[00:09.00]other"));
      final lyrics = await EmbeddedLyrics.forFile(flac.path, trackName: "u");
      expect(lyrics?.provider, EmbeddedLyrics.providerTags);
      expect(lyrics?.lyrics.first.text, "one");
    });

    test("falls back to a plain tag when nothing is synced", () async {
      final flac = await write(
        "v.flac",
        flacBytes([
          streamInfo,
          (
            typeVorbisComment,
            vorbisCommentBody("v", ["UNSYNCEDLYRICS=$plain"]),
          ),
        ]),
      );
      final lyrics = await EmbeddedLyrics.forFile(flac.path, trackName: "v");
      expect(lyrics?.provider, EmbeddedLyrics.providerTags);
      expect(lyrics?.rating, 0);
      expect(lyrics?.lyrics.map((l) => l.text), ["just words", "more words"]);
    });

    test("a non-FLAC file still gets its sidecar, UTF-16 BOM included",
        () async {
      final mp3 = await write("w.mp3", utf8.encode("ID3....not really"));
      final utf16 = BytesBuilder()
        ..add([0xFF, 0xFE])
        ..add(Uint8List.sublistView(
          Uint16List.fromList(synced.codeUnits).buffer.asUint8List(),
        ));
      await write("w.lrc", utf16.toBytes());
      final lyrics = await EmbeddedLyrics.forFile(mp3.path, trackName: "w");
      expect(lyrics?.provider, EmbeddedLyrics.providerSidecar);
      expect(lyrics?.lyrics.map((l) => l.text), ["one", "two"]);
    });

    test("a UTF-8 BOM on a sidecar is stripped", () async {
      final flac = await write("x.flac", flacBytes([streamInfo]));
      await write("x.lrc", [0xEF, 0xBB, 0xBF, ...utf8.encode(synced)]);
      final lyrics = await EmbeddedLyrics.forFile(flac.path, trackName: "x");
      expect(lyrics?.lyrics.first.text, "one");
      expect(lyrics?.lyrics.first.time, const Duration(seconds: 1));
    });

    test("returns null when the file has neither tag nor sidecar", () async {
      final flac = await write(
        "y.flac",
        flacBytes([
          streamInfo,
          (typeVorbisComment, vorbisCommentBody("v", ["TITLE=no lyrics"])),
        ]),
      );
      expect(await EmbeddedLyrics.forFile(flac.path, trackName: "y"), isNull);
    });

    test("a blank LYRICS tag counts as absent", () async {
      final flac = await write(
        "z.flac",
        flacBytes([
          streamInfo,
          (typeVorbisComment, vorbisCommentBody("v", ["LYRICS=  \n "])),
        ]),
      );
      expect(await EmbeddedLyrics.forFile(flac.path, trackName: "z"), isNull);
    });
  });
}
