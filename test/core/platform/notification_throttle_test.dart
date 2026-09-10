import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/platform/impl/notifications/notification_throttle.dart';

void main() {
  final start = DateTime.utc(2026, 9, 1, 9);

  group('NotificationThrottle', () {
    test('allows the first notification for a key', () {
      expect(NotificationThrottle().shouldShow('p1:low', start), isTrue);
    });

    test('blocks a second one inside the window', () {
      final throttle = NotificationThrottle()..record('p1:low', start);
      expect(throttle.shouldShow('p1:low', start.add(const Duration(minutes: 59))), isFalse);
    });

    test('allows again once the window has passed', () {
      final throttle = NotificationThrottle()..record('p1:low', start);
      expect(throttle.shouldShow('p1:low', start.add(const Duration(hours: 1))), isTrue);
    });

    test('keys are independent', () {
      final throttle = NotificationThrottle()..record('p1:low', start);
      expect(throttle.shouldShow('p2:low', start), isTrue);
      expect(throttle.shouldShow('p1:out', start), isTrue);
    });

    test('honours a custom window', () {
      final throttle = NotificationThrottle(window: const Duration(minutes: 5))
        ..record('p1:low', start);
      expect(throttle.shouldShow('p1:low', start.add(const Duration(minutes: 4))), isFalse);
      expect(throttle.shouldShow('p1:low', start.add(const Duration(minutes: 5))), isTrue);
    });

    test('clear forgets everything', () {
      final throttle = NotificationThrottle()
        ..record('p1:low', start)
        ..clear();
      expect(throttle.shouldShow('p1:low', start), isTrue);
    });
  });
}
