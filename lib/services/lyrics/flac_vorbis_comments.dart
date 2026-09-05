import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The `VORBIS_COMMENT` block of a FLAC file: the vendor string plus the
/// `KEY=value` fields. Keys are ASCII and case-insensitive by spec, so they
/// are stored upper-cased; a key may carry several values.
class VorbisComments {
  VorbisComments(this.vendor, Map<String, List<String>> fields)
      : _fields = Map.unmodifiable({
          for (final entry in fields.entries)
            entry.key.toUpperCase(): List<String>.unmodifiable(entry.value),
        });

  final String vendor;
  final Map<String, List<String>> _fields;

  Iterable<String> get keys => _fields.keys;
  bool get isEmpty => _fields.isEmpty;

  /// Every value stored under [key], in file order. Empty when absent.
  List<String> values(String key) => _fields[key.toUpperCase()] ?? const [];

  String? first(String key) => values(key).firstOrNull;
}

/// Parses the body of a `VORBIS_COMMENT` block — the bytes *after* the 4-byte
/// metadata block header. Layout (all integers little-endian):
///
/// ```
/// u32 vendor_length, vendor (UTF-8)
/// u32 user_comment_list_length
/// repeat: u32 length, "KEY=value" (UTF-8)
/// ```
///
/// Tolerant by design: a truncated or malformed block yields whatever fields
/// were intact before the damage rather than throwing. Lyrics are a
/// nice-to-have, and a tagger's off-by-one must not take the page down.
VorbisComments parseVorbisCommentBlock(Uint8List body) {
  final data = ByteData.sublistView(body);
  var offset = 0;

  int? readU32() {
    if (offset + 4 > body.length) return null;
    final value = data.getUint32(offset, Endian.little);
    offset += 4;
    return value;
  }

  String? readString(int length) {
    if (length < 0 || offset + length > body.length) return null;
    final text = utf8.decode(
      Uint8List.sublistView(body, offset, offset + length),
      allowMalformed: true,
    );
    offset += length;
    return text;
  }

  final fields = <String, List<String>>{};
  final vendorLength = readU32();
  final vendor = vendorLength == null ? null : readString(vendorLength);
  if (vendor == null) return VorbisComments("", fields);

  final count = readU32() ?? 0;
  for (var i = 0; i < count; i++) {
    final length = readU32();
    if (length == null) break;
    final entry = readString(length);
    if (entry == null) break;
    final separator = entry.indexOf("=");
    // A field with no "=" or an empty key is not a field.
    if (separator <= 0) continue;
    fields
        .putIfAbsent(entry.substring(0, separator).toUpperCase(), () => [])
        .add(entry.substring(separator + 1));
  }
  return VorbisComments(vendor, fields);
}

const _blockTypeVorbisComment = 4;
// Reserved by the spec; seeing it means the block walk has lost sync.
const _blockTypeInvalid = 127;
// A real comment block is a few KB. Anything past this is damage or hostile,
// and buffering it would only trade a missing lyric for an OOM.
const _maxCommentBlockBytes = 16 << 20;

/// Reads the `VORBIS_COMMENT` block from the FLAC file at [path].
///
/// Only the metadata headers are touched — a PICTURE block in front of the
/// comments is skipped by seeking, never read — so this costs one small read
/// per block regardless of file size. Returns null when the file is not FLAC,
/// carries no comment block, or cannot be read; it never throws for a bad file.
Future<VorbisComments?> readFlacVorbisComments(String path) async {
  RandomAccessFile? file;
  try {
    file = await File(path).open();
    return await _readFromOpenFile(file);
  } on FileSystemException {
    return null;
  } finally {
    await file?.close();
  }
}

bool _isFlacMarker(List<int> bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x66 && // f
    bytes[1] == 0x4C && // L
    bytes[2] == 0x61 && // a
    bytes[3] == 0x43; // C

bool _isId3Marker(List<int> bytes) =>
    bytes.length >= 3 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33;

Future<VorbisComments?> _readFromOpenFile(RandomAccessFile file) async {
  var marker = await file.read(4);
  if (_isId3Marker(marker)) {
    // Some taggers put an ID3v2 tag in front of the FLAC stream. Header:
    // "ID3", version (2), flags (1), syncsafe size (4); a footer flag adds 10.
    final rest = await file.read(6);
    if (rest.length < 6) return null;
    final flags = rest[1];
    final size = ((rest[2] & 0x7F) << 21) |
        ((rest[3] & 0x7F) << 14) |
        ((rest[4] & 0x7F) << 7) |
        (rest[5] & 0x7F);
    await file.setPosition(10 + size + ((flags & 0x10) != 0 ? 10 : 0));
    marker = await file.read(4);
  }
  if (!_isFlacMarker(marker)) return null;

  while (true) {
    final header = await file.read(4);
    if (header.length < 4) return null; // EOF without a comment block
    final isLast = (header[0] & 0x80) != 0;
    final type = header[0] & 0x7F;
    final length = (header[1] << 16) | (header[2] << 8) | header[3];

    if (type == _blockTypeVorbisComment) {
      if (length > _maxCommentBlockBytes) return null;
      // A short read means a truncated file; parse what is there.
      return parseVorbisCommentBlock(await file.read(length));
    }
    if (isLast || type == _blockTypeInvalid) return null;
    await file.setPosition(await file.position() + length);
  }
}
