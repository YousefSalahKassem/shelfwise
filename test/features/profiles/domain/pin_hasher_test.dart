import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/features/profiles/domain/services/pin_hasher.dart';
import 'package:shelfwise/features/profiles/domain/value_objects/pin.dart';

void main() {
  // A small work factor keeps the suite fast; the algorithm is the same.
  const hasher = PinHasher(iterations: 100);

  test('the same PIN and salt always give the same hash', () {
    final salt = hasher.newSalt(Random(1));
    expect(hasher.hash('1234', salt), hasher.hash('1234', salt));
  });

  test('accepts the right PIN and rejects everything else', () {
    final salt = hasher.newSalt();
    final hash = hasher.hash('482913', salt);

    expect(hasher.verify(pin: '482913', hash: hash, salt: salt), isTrue);
    expect(hasher.verify(pin: '482914', hash: hash, salt: salt), isFalse);
    expect(hasher.verify(pin: '48291', hash: hash, salt: salt), isFalse);
    expect(hasher.verify(pin: '', hash: hash, salt: salt), isFalse);
  });

  test('two profiles with the same PIN get different hashes', () {
    final a = hasher.newSalt();
    final b = hasher.newSalt();
    expect(a, isNot(b));
    expect(hasher.hash('1234', a), isNot(hasher.hash('1234', b)));
  });

  test('a salt is 16 random bytes, base64-encoded', () {
    expect(hasher.newSalt().length, 24); // 16 bytes → 24 base64 chars
  });

  test('unreadable stored material fails to verify instead of throwing', () {
    expect(hasher.verify(pin: '1234', hash: 'not-base64!', salt: 'nor-this!'), isFalse);
    expect(hasher.verify(pin: '1234', hash: hasher.hash('1234', hasher.newSalt()), salt: '%%'),
        isFalse);
  });

  test('the work factor changes the hash, so it is part of the stored contract', () {
    final salt = hasher.newSalt(Random(2));
    expect(
      const PinHasher(iterations: 100).hash('1234', salt),
      isNot(const PinHasher(iterations: 200).hash('1234', salt)),
    );
  });

  group('Pin', () {
    test('accepts 4 to 6 digits', () {
      for (final value in ['1234', '12345', '123456']) {
        expect(Pin.isValid(value), isTrue, reason: value);
      }
    });

    test('rejects short, long and non-digit values', () {
      for (final value in ['', '123', '1234567', '12a4', '12 4', '١٢٣٤']) {
        expect(Pin.isValid(value), isFalse, reason: value);
      }
    });
  });
}
