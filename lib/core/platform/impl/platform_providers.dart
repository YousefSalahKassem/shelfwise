// OWNER: A5. Real platform services. Provider names and types are the frozen
// W0 contract — bootstrap and every feature keep working unchanged.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../brand/brand_providers.dart';
import '../../l10n/l10n.dart';
import '../../router/app_router.dart';
import '../../settings/effective_locale.dart';
import '../../utils/core_providers.dart';
import '../file_service.dart';
import '../notification_service.dart';
import '../scanner_service.dart';
import 'files/platform_file_service.dart';
import 'notifications/local_notification_service.dart';
import 'notifications/local_notifications_backend.dart';
import 'scanner/platform_scanner_service.dart';

part 'platform_providers.g.dart';

@Riverpod(keepAlive: true)
ScannerService scannerService(Ref ref) =>
    PlatformScannerService(supportsCamera: defaultSupportsCamera());

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  final brand = ref.watch(brandConfigProvider);
  final service = LocalNotificationService(
    backend: LocalNotificationsBackend(
      appName: brand.appName,
      appUserModelId: 'com.shelfwise.${brand.id}',
    ),
    clock: ref.watch(clockProvider),
    // Read at send time, so a notification follows the language in use now.
    localizations: () => lookupAppLocalizations(ref.read(effectiveLocaleProvider)),
  );

  // Tapping a notification opens the alerts screen (brief: deep-link to /alerts).
  final subscription = service.taps.listen((route) => ref.read(appRouterProvider).go(route));
  ref.onDispose(subscription.cancel);
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
FileService fileService(Ref ref) =>
    PlatformFileService(useShareSheet: defaultUseShareSheet());
