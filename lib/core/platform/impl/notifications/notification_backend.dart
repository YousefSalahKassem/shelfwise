// OWNER: A5. The slice of the notification plugin the service needs, behind a
// tiny interface so the service itself can be tested without platform channels.
import 'package:meta/meta.dart';

@immutable
class NotificationMessage {
  const NotificationMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  /// Stable per product and level, so a newer notice replaces the older one.
  final int id;
  final String title;
  final String body;

  /// Route to open when the notification is tapped.
  final String payload;
}

abstract interface class NotificationBackend {
  /// Sets up the plugin for this platform (Android channel, Darwin categories,
  /// Windows toast identity, web service worker). Called once, lazily.
  Future<void> initialize({
    required void Function(String payload) onTap,
    required String channelName,
    required String channelDescription,
  });

  /// Asks the OS/browser. On web this must happen inside a user tap.
  Future<bool> requestPermission();

  /// False when the platform is certain a notification would not be shown
  /// (browser permission not granted yet). Never throws.
  Future<bool> canShow();

  Future<void> show(NotificationMessage message);

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload();
}
