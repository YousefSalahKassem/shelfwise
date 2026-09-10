// OWNER: A5. The only file that talks to `flutter_local_notifications`.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_backend.dart';

/// Android notification channel for low-stock alerts (brief: "Low stock").
const String kLowStockChannelId = 'low_stock';

/// Identifies the toast activation callback on Windows. Fixed for the app.
const String _windowsGuid = '2f7c9b8e-4d51-4e2a-9a0c-7f3b6e5d1a42';

class LocalNotificationsBackend implements NotificationBackend {
  LocalNotificationsBackend({
    required this.appName,
    required this.appUserModelId,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Shown as the toast source on Windows and as the default action on Linux.
  final String appName;

  /// `CompanyName.ProductName…` — one per brand so toasts are not shared.
  final String appUserModelId;

  final FlutterLocalNotificationsPlugin _plugin;

  String _channelName = 'Low stock';
  String? _channelDescription;

  @override
  Future<void> initialize({
    required void Function(String payload) onTap,
    required String channelName,
    required String channelDescription,
  }) async {
    _channelName = channelName;
    _channelDescription = channelDescription;

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked later, from a user tap (web and iOS both want that).
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        linux: LinuxInitializationSettings(defaultActionName: appName),
        windows: WindowsInitializationSettings(
          appName: appName,
          appUserModelId: appUserModelId,
          guid: _windowsGuid,
        ),
        web: const WebInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );

    if (_isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              kLowStockChannelId,
              channelName,
              description: channelDescription,
              importance: Importance.high,
            ),
          );
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      final web = _plugin
          .resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>();
      return await web?.requestNotificationsPermission() ?? false;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      case TargetPlatform.iOS:
        final ios = _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      case TargetPlatform.macOS:
        final macos = _plugin
            .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
        return await macos?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        // No permission model — notifications work as soon as the app can post.
        return true;
    }
  }

  @override
  Future<bool> canShow() async {
    if (!kIsWeb) return true;
    // Showing without browser permission throws, so check first.
    final web =
        _plugin.resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>();
    return web?.permissionStatus == WebNotificationPermission.granted;
  }

  @override
  Future<void> show(NotificationMessage message) => _plugin.show(
        id: message.id,
        title: message.title,
        body: message.body,
        payload: message.payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            kLowStockChannelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
          linux: const LinuxNotificationDetails(),
          windows: const WindowsNotificationDetails(),
          web: const WebNotificationDetails(),
        ),
      );

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
