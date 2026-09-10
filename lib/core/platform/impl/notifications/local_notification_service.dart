// OWNER: A5. Real [NotificationService] — low-stock alerts on every platform.
import 'dart:async';
import 'dart:developer' as developer;

import '../../../domain/stock_status.dart';
import '../../../l10n/l10n.dart';
import '../../../router/route_paths.dart';
import '../../../utils/clock.dart';
import '../../notification_service.dart';
import 'notification_backend.dart';
import 'notification_throttle.dart';

class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    required this.backend,
    required this.clock,
    required this.localizations,
    this.route = RoutePaths.alerts,
    Duration throttleWindow = const Duration(hours: 1),
  }) : _throttle = NotificationThrottle(window: throttleWindow);

  final NotificationBackend backend;
  final Clock clock;

  /// Read at send time, so the text follows the language in use right now.
  final AppLocalizations Function() localizations;

  /// Route opened when a notification is tapped.
  final String route;

  final NotificationThrottle _throttle;

  late final StreamController<String> _controller =
      StreamController<String>.broadcast(onListen: _flushPendingTap);
  String? _pendingTap;
  Future<void>? _initialization;

  @override
  Stream<String> get taps => _controller.stream;

  @override
  Future<bool> requestPermission() async {
    try {
      await _ensureInitialized();
      return await backend.requestPermission();
    } on Object catch (error, stackTrace) {
      _log('requestPermission failed', error, stackTrace);
      return false;
    }
  }

  @override
  Future<void> showLowStock(LowStockNotice notice) async {
    try {
      await _ensureInitialized();
      if (!await backend.canShow()) return;

      final key = '${notice.productId}:${notice.level.name}';
      final now = clock.now();
      if (!_throttle.shouldShow(key, now)) return;

      final l10n = localizations();
      final out = notice.level == StockStatus.out;
      await backend.show(
        NotificationMessage(
          id: notificationIdFor(notice),
          title: out ? l10n.platform_outOfStockTitle : l10n.platform_lowStockTitle,
          body: out
              ? l10n.platform_outOfStockBody(notice.productName)
              : l10n.platform_lowStockBody(notice.productName, notice.quantityText),
          payload: route,
        ),
      );
      _throttle.record(key, now);
    } on Object catch (error, stackTrace) {
      // An alert that cannot be shown must never break the write that caused it.
      _log('showLowStock failed', error, stackTrace);
    }
  }

  Future<void> _ensureInitialized() {
    final l10n = localizations();
    return _initialization ??= backend.initialize(
      onTap: _emitTap,
      channelName: l10n.platform_notificationChannelName,
      channelDescription: l10n.platform_notificationChannelDescription,
    ).then((_) async {
      final payload = await backend.launchPayload();
      if (payload != null && payload.isNotEmpty) _emitTap(payload);
    });
  }

  void _emitTap(String target) {
    if (_controller.isClosed) return;
    // Nobody is listening during start-up; keep it until the app subscribes.
    if (_controller.hasListener) {
      _controller.add(target);
    } else {
      _pendingTap = target;
    }
  }

  void _flushPendingTap() {
    final pending = _pendingTap;
    if (pending == null) return;
    _pendingTap = null;
    scheduleMicrotask(() {
      if (!_controller.isClosed) _controller.add(pending);
    });
  }

  void _log(String message, Object error, StackTrace stackTrace) => developer.log(
        message,
        name: 'shelfwise.notifications',
        error: error,
        stackTrace: stackTrace,
      );

  Future<void> dispose() => _controller.close();
}

/// Same product + same level ⇒ same id, so the platform replaces the old
/// notification instead of stacking a new one.
int notificationIdFor(LowStockNotice notice) =>
    Object.hash(notice.productId, notice.level) & 0x7FFFFFFF;
