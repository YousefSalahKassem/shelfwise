import 'app_event.dart';

export 'app_event.dart';
export 'impl/analytics_impl.dart' show analyticsServiceProvider;

/// Logs usage events. Must never throw into the UI.
abstract interface class AnalyticsService {
  Future<void> log(AppEvent event, [Map<String, Object?> props = const {}]);
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();
  @override
  Future<void> log(AppEvent event, [Map<String, Object?> props = const {}]) async {}
}

/// Test helper that remembers what was logged.
class RecordingAnalyticsService implements AnalyticsService {
  final events = <(AppEvent, Map<String, Object?>)>[];
  @override
  Future<void> log(AppEvent event, [Map<String, Object?> props = const {}]) async =>
      events.add((event, props));
}
