// OWNER: A5. Real [ScannerService]: camera where there is one, USB/Bluetooth
// keyboard-wedge dialog everywhere else.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../scanner_service.dart';
import 'keyboard_wedge_dialog.dart';
import 'scan_page.dart';

/// True on the platforms where `mobile_scanner` can drive a camera.
/// Windows and Linux shops use a USB scanner instead (TECHNICAL_STRUCTURE §11).
bool defaultSupportsCamera() {
  if (kIsWeb) return true;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
}

class PlatformScannerService implements ScannerService {
  const PlatformScannerService({required this.supportsCamera});

  @override
  final bool supportsCamera;

  @override
  Future<String?> scan(BuildContext context) {
    if (!supportsCamera) return showKeyboardWedgeDialog(context);
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (context) => const ScanPage(),
      ),
    );
  }
}
