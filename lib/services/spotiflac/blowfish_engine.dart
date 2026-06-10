import 'dart:typed_data';

import 'package:sonolyth/services/spotiflac/blowfish_constants.dart';

/// Minimal Blowfish block cipher (8-byte blocks) in pure Dart, with CBC
/// decryption. Only what the Deezer download path needs — no padding, no
/// encryption. Verified against the standard all-zero-key test vector
/// (plaintext 0x0000000000000000 -> ciphertext 0x4EF99745 6198DD78).
class BlowfishEngine {
  static const _mask = 0xFFFFFFFF;

  final Uint32List _p = Uint32List(18);
  final Uint32List _s0 = Uint32List(256);
  final Uint32List _s1 = Uint32List(256);
  final Uint32List _s2 = Uint32List(256);
  final Uint32List _s3 = Uint32List(256);

  BlowfishEngine(Uint8List key) {
    _p.setAll(0, blowfishP);
    _s0.setAll(0, blowfishS0);
    _s1.setAll(0, blowfishS1);
    _s2.setAll(0, blowfishS2);
    _s3.setAll(0, blowfishS3);

    var j = 0;
    for (var i = 0; i < 18; i++) {
      var data = 0;
      for (var k = 0; k < 4; k++) {
        data = ((data << 8) | key[j]) & _mask;
        j = (j + 1) % key.length;
      }
      _p[i] ^= data;
    }

    var l = 0;
    var r = 0;
    for (var i = 0; i < 18; i += 2) {
      final encrypted = _encryptBlock(l, r);
      l = encrypted[0];
      r = encrypted[1];
      _p[i] = l;
      _p[i + 1] = r;
    }
    for (final box in [_s0, _s1, _s2, _s3]) {
      for (var i = 0; i < 256; i += 2) {
        final encrypted = _encryptBlock(l, r);
        l = encrypted[0];
        r = encrypted[1];
        box[i] = l;
        box[i + 1] = r;
      }
    }
  }

  int _f(int x) {
    final a = (x >> 24) & 0xFF;
    final b = (x >> 16) & 0xFF;
    final c = (x >> 8) & 0xFF;
    final d = x & 0xFF;
    var y = (_s0[a] + _s1[b]) & _mask;
    y ^= _s2[c];
    y = (y + _s3[d]) & _mask;
    return y;
  }

  List<int> _encryptBlock(int l, int r) {
    var xl = l;
    var xr = r;
    xl ^= _p[0];
    for (var i = 1; i <= 16; i++) {
      if (i.isOdd) {
        xr = (xr ^ _f(xl) ^ _p[i]) & _mask;
      } else {
        xl = (xl ^ _f(xr) ^ _p[i]) & _mask;
      }
    }
    xr ^= _p[17];
    return [xr & _mask, xl & _mask];
  }

  List<int> _decryptBlock(int l, int r) {
    var xl = l;
    var xr = r;
    xl ^= _p[17];
    for (var i = 16; i >= 1; i--) {
      if (i.isEven) {
        xr = (xr ^ _f(xl) ^ _p[i]) & _mask;
      } else {
        xl = (xl ^ _f(xr) ^ _p[i]) & _mask;
      }
    }
    xr ^= _p[0];
    return [xr & _mask, xl & _mask];
  }

  /// Decrypts [input] (a multiple of 8 bytes) in CBC mode with the given [iv].
  Uint8List decryptCbc(Uint8List input, Uint8List iv) {
    final output = Uint8List(input.length);
    final view = ByteData.sublistView(input);
    final outView = ByteData.sublistView(output);

    var prevL = iv.buffer.asByteData().getUint32(0, Endian.big);
    var prevR = iv.buffer.asByteData().getUint32(4, Endian.big);

    for (var offset = 0; offset + 8 <= input.length; offset += 8) {
      final cipherL = view.getUint32(offset, Endian.big);
      final cipherR = view.getUint32(offset + 4, Endian.big);

      final decrypted = _decryptBlock(cipherL, cipherR);
      outView.setUint32(offset, decrypted[0] ^ prevL, Endian.big);
      outView.setUint32(offset + 4, decrypted[1] ^ prevR, Endian.big);

      prevL = cipherL;
      prevR = cipherR;
    }
    return output;
  }
}
