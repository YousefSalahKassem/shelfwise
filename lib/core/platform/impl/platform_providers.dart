// OWNER: A5 (replaces the bodies with real implementations; keep names/types).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../fakes.dart';
import '../file_service.dart';
import '../notification_service.dart';
import '../scanner_service.dart';

part 'platform_providers.g.dart';

@Riverpod(keepAlive: true)
ScannerService scannerService(Ref ref) => FakeScannerService();

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => FakeNotificationService();

@Riverpod(keepAlive: true)
FileService fileService(Ref ref) => FakeFileService();
