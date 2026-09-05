import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/services/logger/log_file_trimmer.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group("logTrimCutIndex", () {
    test("keeps everything when the buffer fits", () {
      expect(logTrimCutIndex(_bytes("a\nb\n"), 4), 0);
      expect(logTrimCutIndex(_bytes("a\nb\n"), 100), 0);
      expect(logTrimCutIndex(Uint8List(0), 10), 0);
    });

    test("advances to the first line boundary inside the kept window", () {
      // "line1\nline2\nline3\n" — keep 8 bytes: window starts inside "line2".
      final b = _bytes("line1\nline2\nline3\n");
      final cut = logTrimCutIndex(b, 8);
      expect(utf8.decode(b.sublist(cut)), "line3\n");
    });

    test("cuts exactly at a boundary when the window starts on one", () {
      final b = _bytes("line1\nline2\nline3\n");
      // window = "line3\n" exactly (6 bytes) -> start is already a line start,
      // but the scan finds the newline at the END of line3 first; that would
      // keep nothing, so the raw start wins.
      final cut = logTrimCutIndex(b, 6);
      expect(utf8.decode(b.sublist(cut)), "line3\n");
    });

    test("falls back to the raw offset when the tail has no newline", () {
      final b = _bytes("x" * 100);
      expect(logTrimCutIndex(b, 10), 90);
    });

    test("falls back to the raw offset when the only newline is the last byte",
        () {
      final b = _bytes("${"x" * 100}\n");
      // window covers the final 10 bytes; the only \n is the last one.
      expect(logTrimCutIndex(b, 10), 91);
    });

    test("negative keep behaves as zero", () {
      expect(logTrimCutIndex(_bytes("abc"), -5), 3);
    });
  });

  _clipboardTests();

  group("trimLogFile", () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp("sonolyth_logtrim_");
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test("returns 0 for a missing file and creates nothing", () async {
      final f = File("${dir.path}/.spotube_logs");
      expect(await trimLogFile(f, maxBytes: 10, keepBytes: 5), 0);
      expect(await f.exists(), isFalse);
    });

    test("leaves a file at or under the cap untouched", () async {
      final f = File("${dir.path}/.spotube_logs");
      const body = "one\ntwo\nthree\n";
      await f.writeAsString(body);
      final len = await trimLogFile(f, maxBytes: body.length, keepBytes: 4);
      expect(len, body.length);
      expect(await f.readAsString(), body);
    });

    test("trims an oversized file to the newest whole lines plus the marker",
        () async {
      final f = File("${dir.path}/.spotube_logs");
      final lines = List.generate(200, (i) => "[t$i] line number $i");
      await f.writeAsString("${lines.join("\n")}\n");
      final before = await f.length();

      final after = await trimLogFile(f, maxBytes: before - 1, keepBytes: 500);

      final text = await f.readAsString();
      expect(after, text.length);
      expect(after, lessThanOrEqualTo(500 + kLogFileTrimMarker.length));
      expect(text, startsWith(kLogFileTrimMarker));
      // The first surviving line is a complete one.
      final firstKept = text.substring(kLogFileTrimMarker.length).split("\n")[0];
      expect(lines, contains(firstKept));
      // The newest line is intact at the end.
      expect(text, endsWith("${lines.last}\n"));
      // No temp file left behind.
      expect(await File("${f.path}.trim").exists(), isFalse);
    });

    test("a second call right after a trim is a no-op", () async {
      final f = File("${dir.path}/.spotube_logs");
      await f.writeAsString("${List.filled(100, "0123456789").join("\n")}\n");
      final first = await trimLogFile(f, maxBytes: 200, keepBytes: 100);
      final snapshot = await f.readAsString();
      final second = await trimLogFile(f, maxBytes: 200, keepBytes: 100);
      expect(second, first);
      expect(await f.readAsString(), snapshot);
    });
  });
}

void _clipboardTests() {
  group("clipboardTail", () {
    test("returns the text unchanged when it fits", () {
      const t = "a\nb\nc\n";
      expect(clipboardTail(t, maxChars: t.length), same(t));
      expect(clipboardTail(t, maxChars: 1000), same(t));
      expect(clipboardTail("", maxChars: 0), "");
    });

    test("keeps the newest whole lines behind the marker", () {
      final lines = List.generate(50, (i) => "[t$i] entry $i");
      final text = "${lines.join("\n")}\n";
      final out = clipboardTail(text, maxChars: 120);
      expect(out, startsWith(kLogFileTrimMarker));
      expect(out.length, lessThanOrEqualTo(120 + kLogFileTrimMarker.length));
      final body = out.substring(kLogFileTrimMarker.length);
      expect(lines, contains(body.split("\n").first));
      expect(out, endsWith("${lines.last}\n"));
    });

    test("falls back to a raw cut when the tail has no usable newline", () {
      expect(clipboardTail("x" * 100, maxChars: 10),
          "${kLogFileTrimMarker}${"x" * 10}");
      // Only newline is the final byte: cutting after it would keep nothing.
      expect(clipboardTail("${"y" * 100}\n", maxChars: 10),
          "$kLogFileTrimMarker${"y" * 9}\n");
    });
  });
}
