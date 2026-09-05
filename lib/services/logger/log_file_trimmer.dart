import 'dart:io';
import 'dart:typed_data';

/// Size cap for `.spotube_logs`. Once the file passes this, it is trimmed
/// in place down to [kLogFileKeepBytes].
///
/// The file used to grow without bound: every `diag` line in a debug build
/// and every error block in a release build was appended forever, and the
/// only thing that ever shrank it was the trash button on the Logs page.
/// 2 MiB is weeks of release errors or days of debug tracing; trimming to
/// half the cap means a trim happens at most once per megabyte written.
const int kLogFileMaxBytes = 2 * 1024 * 1024;

/// How much of the newest content survives a trim.
const int kLogFileKeepBytes = 1024 * 1024;

/// First line of a trimmed file, so a reader knows the head is gone rather
/// than assuming the app only just started logging.
const String kLogFileTrimMarker = "[log trimmed: older entries removed]\n";

/// Byte offset from which the newest [keepBytes] of [bytes] should be kept,
/// moved forward to the first line boundary so the surviving text never
/// starts mid-line.
///
/// Returns 0 when nothing needs to go. Falls back to the raw offset when the
/// tail holds no usable newline (a single giant line, or the only newline is
/// the file's final byte — cutting there would keep nothing).
int logTrimCutIndex(Uint8List bytes, int keepBytes) {
  if (keepBytes < 0) keepBytes = 0;
  if (bytes.length <= keepBytes) return 0;
  final start = bytes.length - keepBytes;
  for (var i = start; i < bytes.length; i++) {
    if (bytes[i] == 0x0A /* \n */) {
      final cut = i + 1;
      return cut < bytes.length ? cut : start;
    }
  }
  return start;
}

/// Trims [file] to its newest [keepBytes] (plus [kLogFileTrimMarker]) when it
/// is larger than [maxBytes]. Returns the file's length afterwards — the
/// unchanged length when no trim was needed, 0 when the file does not exist.
///
/// The trimmed content is written to a sibling temp file and renamed over the
/// original, so a crash mid-trim leaves either the old file or the new one,
/// never a half-written log.
Future<int> trimLogFile(
  File file, {
  int maxBytes = kLogFileMaxBytes,
  int keepBytes = kLogFileKeepBytes,
}) async {
  if (!await file.exists()) return 0;
  final length = await file.length();
  if (length <= maxBytes) return length;

  final bytes = await file.readAsBytes();
  final cut = logTrimCutIndex(bytes, keepBytes);
  final tail = Uint8List.sublistView(bytes, cut);

  final builder = BytesBuilder(copy: false)
    ..add(kLogFileTrimMarker.codeUnits)
    ..add(tail);
  final trimmed = builder.takeBytes();

  final tmp = File("${file.path}.trim");
  await tmp.writeAsBytes(trimmed, flush: true);
  await tmp.rename(file.path);
  return trimmed.length;
}

/// Upper bound on what the Logs page hands to the clipboard.
///
/// Android moves a clip through a single binder transaction with a 1 MB
/// budget for the whole parcel; copying the 1 MiB trimmed log threw
/// `TransactionTooLargeException: data parcel size 1062512 bytes` on the
/// emulator (API 35). 256 Ki chars is at most 512 KB on the wire and far
/// more than any bug report needs.
const int kLogClipboardMaxChars = 256 * 1024;

/// The newest [maxChars] of [text], moved forward to a line boundary and led
/// by [kLogFileTrimMarker] when anything was dropped. [text] itself when it
/// already fits. Same fallback rules as [logTrimCutIndex].
String clipboardTail(String text, {int maxChars = kLogClipboardMaxChars}) {
  if (maxChars < 0) maxChars = 0;
  if (text.length <= maxChars) return text;
  final start = text.length - maxChars;
  final nl = text.indexOf("\n", start);
  final cut = (nl == -1 || nl + 1 >= text.length) ? start : nl + 1;
  return kLogFileTrimMarker + text.substring(cut);
}
