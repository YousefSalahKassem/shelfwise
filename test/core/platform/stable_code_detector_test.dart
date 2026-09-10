import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/platform/impl/scanner/stable_code_detector.dart';

void main() {
  group('StableCodeDetector', () {
    test('accepts a code only after it has been seen twice', () {
      final detector = StableCodeDetector();
      expect(detector.offer('6221031492025'), isNull);
      expect(detector.offer('6221031492025'), '6221031492025');
    });

    test('a different code restarts the count', () {
      final detector = StableCodeDetector();
      expect(detector.offer('111'), isNull);
      expect(detector.offer('222'), isNull);
      expect(detector.offer('111'), isNull);
      expect(detector.offer('111'), '111');
    });

    test('ignores null, empty and whitespace-only detections', () {
      final detector = StableCodeDetector();
      expect(detector.offer(null), isNull);
      expect(detector.offer(''), isNull);
      expect(detector.offer('   '), isNull);
      expect(detector.offer(' 999 '), isNull);
      expect(detector.offer('999'), '999');
    });

    test('reset forgets the candidate', () {
      final detector = StableCodeDetector();
      detector.offer('123');
      detector.reset();
      expect(detector.offer('123'), isNull);
    });

    test('confirmations: 1 accepts the first detection', () {
      expect(StableCodeDetector(confirmations: 1).offer('123'), '123');
    });
  });
}
