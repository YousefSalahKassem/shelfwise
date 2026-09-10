// OWNER: A5. Pure Dart — no Flutter.

/// Keeps a shop owner from being buried under alerts: at most one notification
/// per key (product + level) per [window].
class NotificationThrottle {
  NotificationThrottle({this.window = const Duration(hours: 1)});

  final Duration window;
  final Map<String, DateTime> _lastShown = {};

  bool shouldShow(String key, DateTime now) {
    final last = _lastShown[key];
    return last == null || now.difference(last) >= window;
  }

  /// Call after the notification was actually handed to the platform.
  void record(String key, DateTime now) {
    _lastShown[key] = now;
    // Entries older than the window can never block anything again.
    _lastShown.removeWhere((_, at) => now.difference(at) >= window);
  }

  void clear() => _lastShown.clear();
}
