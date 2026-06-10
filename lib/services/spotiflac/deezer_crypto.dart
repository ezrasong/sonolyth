import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sonolyth/services/spotiflac/blowfish_engine.dart';

/// Decrypts a Deezer CDN stream. Deezer encrypts only every third 2048-byte
/// chunk with Blowfish-CBC; the per-track key is derived from md5(trackId)
/// XOR'd with a fixed secret. Ported from the SpotiFLAC `deezer` extension.
abstract class DeezerCrypto {
  static const _secret = "g4el58wc0zvf9na1";
  static final _iv = Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7]);
  static const _chunkSize = 2048;

  static Uint8List _blowfishKey(String trackId) {
    final md5Hex = md5.convert(trackId.codeUnits).toString();
    final key = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      key[i] = md5Hex.codeUnitAt(i) ^
          md5Hex.codeUnitAt(i + 16) ^
          _secret.codeUnitAt(i);
    }
    return key;
  }

  static Uint8List decrypt(Uint8List input, String trackId) {
    final engine = BlowfishEngine(_blowfishKey(trackId));
    final output = Uint8List(input.length);

    var offset = 0;
    var chunkIndex = 0;
    while (offset < input.length) {
      final end = (offset + _chunkSize <= input.length)
          ? offset + _chunkSize
          : input.length;
      final chunk = Uint8List.sublistView(input, offset, end);

      if (chunk.length == _chunkSize && chunkIndex % 3 == 0) {
        output.setRange(offset, end, engine.decryptCbc(chunk, _iv));
      } else {
        output.setRange(offset, end, chunk);
      }

      offset = end;
      chunkIndex++;
    }
    return output;
  }
}
