import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/services/spotiflac/blowfish_engine.dart';

void main() {
  test('decrypts the standard all-zero-key Blowfish test vector', () {
    // Key = 0x0000000000000000, plaintext 0x0000000000000000 encrypts to
    // 0x4EF99745 6198DD78 (Schneier's reference vector). Decrypting the
    // ciphertext with CBC and a zero IV must return the zero plaintext.
    final key = Uint8List(8); // all zero
    final iv = Uint8List(8); // all zero
    final ciphertext = Uint8List.fromList(
      [0x4E, 0xF9, 0x97, 0x45, 0x61, 0x98, 0xDD, 0x78],
    );

    final engine = BlowfishEngine(key);
    final plaintext = engine.decryptCbc(ciphertext, iv);

    expect(plaintext, Uint8List(8));
  });
}
