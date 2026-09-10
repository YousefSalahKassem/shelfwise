import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Salted PBKDF2-HMAC-SHA256 hashing of profile PINs (TECHNICAL_STRUCTURE §15).
///
/// Pure Dart so it can live in `domain/`. The salt and the derived key are
/// stored base64-encoded in `profiles.pin_salt` / `profiles.pin_hash`.
/// [iterations] is deliberately modest: a PIN has at most a million
/// combinations, so the work factor is a speed bump, not the defence — the
/// defence is the attempt lockout ([PinAttemptTracker]) and the fact that the
/// database never leaves the device.
class PinHasher {
  const PinHasher({this.iterations = 10000, this.keyLength = 32, this.saltLength = 16});

  final int iterations;
  final int keyLength;
  final int saltLength;

  /// A new random salt, base64-encoded.
  String newSalt([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(saltLength);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return base64Encode(bytes);
  }

  /// Derived key for [pin] and a base64 [salt], base64-encoded.
  String hash(String pin, String salt) =>
      base64Encode(_pbkdf2(utf8.encode(pin), base64Decode(salt)));

  /// Constant-time comparison of [pin] against a stored hash.
  bool verify({required String pin, required String hash, required String salt}) {
    final List<int> expected;
    try {
      expected = base64Decode(hash);
    } on FormatException {
      return false;
    }
    final List<int> actual;
    try {
      actual = _pbkdf2(utf8.encode(pin), base64Decode(salt));
    } on FormatException {
      return false;
    }
    return _constantTimeEquals(expected, actual);
  }

  Uint8List _pbkdf2(List<int> password, List<int> salt) {
    final hmac = Hmac(sha256, password);
    final out = Uint8List(keyLength);
    const blockSize = 32; // SHA-256 output
    final blocks = (keyLength + blockSize - 1) ~/ blockSize;
    var offset = 0;
    for (var block = 1; block <= blocks; block++) {
      final input = <int>[...salt, block >> 24 & 0xff, block >> 16 & 0xff, block >> 8 & 0xff, block & 0xff];
      var u = Uint8List.fromList(hmac.convert(input).bytes);
      final acc = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < acc.length; j++) {
          acc[j] ^= u[j];
        }
      }
      final take = min(blockSize, keyLength - offset);
      out.setRange(offset, offset + take, acc);
      offset += take;
    }
    return out;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    for (var i = 0; i < a.length && i < b.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
