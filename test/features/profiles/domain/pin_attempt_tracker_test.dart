import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/features/profiles/domain/services/pin_attempt_tracker.dart';

void main() {
  final start = DateTime.utc(2026, 9, 10, 12);

  test('five wrong PINs start a 30 second cooldown', () {
    final tracker = PinAttemptTracker();

    for (var i = 0; i < 4; i++) {
      tracker.recordFailure('p1', start);
      expect(tracker.isLockedOut('p1', start), isFalse, reason: 'after ${i + 1} tries');
    }
    tracker.recordFailure('p1', start);

    expect(tracker.isLockedOut('p1', start), isTrue);
    expect(tracker.cooldownSeconds('p1', start), 30);
  });

  test('the cooldown counts down and then clears', () {
    final tracker = PinAttemptTracker();
    for (var i = 0; i < 5; i++) {
      tracker.recordFailure('p1', start);
    }

    expect(tracker.cooldownSeconds('p1', start.add(const Duration(seconds: 20))), 10);
    expect(tracker.cooldownSeconds('p1', start.add(const Duration(seconds: 30))), isNull);
    expect(tracker.isLockedOut('p1', start.add(const Duration(seconds: 31))), isFalse);
  });

  test('after a cooldown the count starts again from zero', () {
    final tracker = PinAttemptTracker();
    for (var i = 0; i < 5; i++) {
      tracker.recordFailure('p1', start);
    }
    final later = start.add(const Duration(seconds: 31));
    expect(tracker.isLockedOut('p1', later), isFalse);

    tracker.recordFailure('p1', later);
    expect(tracker.isLockedOut('p1', later), isFalse);
  });

  test('a correct PIN clears the failures', () {
    final tracker = PinAttemptTracker();
    for (var i = 0; i < 4; i++) {
      tracker.recordFailure('p1', start);
    }
    tracker.recordSuccess('p1');

    for (var i = 0; i < 4; i++) {
      tracker.recordFailure('p1', start);
    }
    expect(tracker.isLockedOut('p1', start), isFalse);
  });

  test('profiles are counted separately', () {
    final tracker = PinAttemptTracker();
    for (var i = 0; i < 5; i++) {
      tracker.recordFailure('p1', start);
    }
    expect(tracker.isLockedOut('p1', start), isTrue);
    expect(tracker.isLockedOut('p2', start), isFalse);
  });
}
