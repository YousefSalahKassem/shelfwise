import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/domain/stock_status.dart';
import 'package:shelfwise/core/l10n/l10n.dart';
import 'package:shelfwise/core/platform/impl/notifications/local_notification_service.dart';
import 'package:shelfwise/core/platform/impl/notifications/notification_backend.dart';
import 'package:shelfwise/core/platform/notification_service.dart';
import 'package:shelfwise/core/router/route_paths.dart';
import 'package:shelfwise/core/utils/clock.dart';

class FakeBackend implements NotificationBackend {
  FakeBackend({this.permission = true, this.showable = true, this.launch});

  final shown = <NotificationMessage>[];
  bool permission;
  bool showable;
  String? launch;
  int initializations = 0;
  String? channelName;
  bool throwOnShow = false;
  void Function(String payload)? onTap;

  @override
  Future<void> initialize({
    required void Function(String payload) onTap,
    required String channelName,
    required String channelDescription,
  }) async {
    initializations++;
    this.onTap = onTap;
    this.channelName = channelName;
  }

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<bool> canShow() async => showable;

  @override
  Future<void> show(NotificationMessage message) async {
    if (throwOnShow) throw StateError('no permission');
    shown.add(message);
  }

  @override
  Future<String?> launchPayload() async => launch;
}

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  final arabic = lookupAppLocalizations(const Locale('ar'));
  final start = DateTime.utc(2026, 9, 1, 9);

  LocalNotificationService serviceWith(
    FakeBackend backend, {
    Clock? clock,
    AppLocalizations? l10n,
  }) =>
      LocalNotificationService(
        backend: backend,
        clock: clock ?? FixedClock(start),
        localizations: () => l10n ?? english,
      );

  const lowMilk = LowStockNotice(
    productId: 'prod-1',
    productName: 'Milk 1L',
    level: StockStatus.low,
    quantityText: '2',
  );
  const outMilk = LowStockNotice(
    productId: 'prod-1',
    productName: 'Milk 1L',
    level: StockStatus.out,
    quantityText: '0',
  );

  test('shows a low-stock notification with the product name and quantity', () async {
    final backend = FakeBackend();
    await serviceWith(backend).showLowStock(lowMilk);

    expect(backend.shown, hasLength(1));
    expect(backend.shown.single.title, english.platform_lowStockTitle);
    expect(backend.shown.single.body, contains('Milk 1L'));
    expect(backend.shown.single.body, contains('2'));
    expect(backend.shown.single.payload, RoutePaths.alerts);
  });

  test('out of stock uses its own title and body', () async {
    final backend = FakeBackend();
    await serviceWith(backend).showLowStock(outMilk);

    expect(backend.shown.single.title, english.platform_outOfStockTitle);
    expect(backend.shown.single.body, english.platform_outOfStockBody('Milk 1L'));
  });

  test('uses the language that is active when the notification is sent', () async {
    final backend = FakeBackend();
    await serviceWith(backend, l10n: arabic).showLowStock(lowMilk);

    expect(backend.shown.single.title, arabic.platform_lowStockTitle);
  });

  test('initialises once and names the Android channel in the user language', () async {
    final backend = FakeBackend();
    final service = serviceWith(backend);
    await service.showLowStock(lowMilk);
    await service.showLowStock(outMilk);

    expect(backend.initializations, 1);
    expect(backend.channelName, english.platform_notificationChannelName);
  });

  test('at most one notification per product per level per hour', () async {
    final backend = FakeBackend();
    final clock = FixedClock(start);
    final service = serviceWith(backend, clock: clock);

    await service.showLowStock(lowMilk);
    await service.showLowStock(lowMilk);
    expect(backend.shown, hasLength(1));

    // A different level for the same product is a different alert.
    await service.showLowStock(outMilk);
    expect(backend.shown, hasLength(2));

    clock.advance(const Duration(minutes: 59));
    await service.showLowStock(lowMilk);
    expect(backend.shown, hasLength(2));

    clock.advance(const Duration(minutes: 1));
    await service.showLowStock(lowMilk);
    expect(backend.shown, hasLength(3));
  });

  test('a blocked notification does not consume the throttle window', () async {
    final backend = FakeBackend(showable: false);
    final clock = FixedClock(start);
    final service = serviceWith(backend, clock: clock);

    await service.showLowStock(lowMilk);
    expect(backend.shown, isEmpty);

    backend.showable = true;
    await service.showLowStock(lowMilk);
    expect(backend.shown, hasLength(1));
  });

  test('the same product and level always reuse one notification id', () async {
    expect(notificationIdFor(lowMilk), notificationIdFor(lowMilk));
    expect(notificationIdFor(lowMilk), isNot(notificationIdFor(outMilk)));
    expect(notificationIdFor(lowMilk), greaterThanOrEqualTo(0));
  });

  test('a failing platform never throws into the caller', () async {
    final backend = FakeBackend()..throwOnShow = true;
    await expectLater(serviceWith(backend).showLowStock(lowMilk), completes);
  });

  test('requestPermission passes the platform answer through', () async {
    expect(await serviceWith(FakeBackend()).requestPermission(), isTrue);
    expect(await serviceWith(FakeBackend(permission: false)).requestPermission(), isFalse);
  });

  test('tapping a notification emits its route', () async {
    final backend = FakeBackend();
    final service = serviceWith(backend);
    final routes = <String>[];
    final subscription = service.taps.listen(routes.add);
    addTearDown(subscription.cancel);

    await service.requestPermission();
    backend.onTap!(RoutePaths.alerts);
    await pumpEventQueue();

    expect(routes, [RoutePaths.alerts]);
  });

  test('a notification that launched the app reaches a late listener', () async {
    final backend = FakeBackend(launch: RoutePaths.alerts);
    final service = serviceWith(backend);
    await service.requestPermission();

    final routes = <String>[];
    final subscription = service.taps.listen(routes.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    expect(routes, [RoutePaths.alerts]);
  });
}
