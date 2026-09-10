import 'package:flutter/widgets.dart';

/// Barcode scanning. Camera on Android/iOS/macOS/Web, keyboard-wedge
/// (USB scanner) elsewhere — implementations by A5.
abstract interface class ScannerService {
  /// True when a camera scanner is available on this platform.
  bool get supportsCamera;

  /// Opens the scanner and returns the scanned code, or null if cancelled.
  Future<String?> scan(BuildContext context);
}
