// OWNER: A6 (replaces the body to write to `app_events`).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../analytics_service.dart';

part 'analytics_impl.g.dart';

@Riverpod(keepAlive: true)
AnalyticsService analyticsService(Ref ref) => const NoopAnalyticsService();
