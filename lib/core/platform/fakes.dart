import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'file_service.dart';
import 'notification_service.dart';
import 'scanner_service.dart';

/// Returns [nextCode] (settable in tests).
class FakeScannerService implements ScannerService {
  FakeScannerService({this.nextCode});
  String? nextCode;
  @override
  bool get supportsCamera => false;
  @override
  Future<String?> scan(BuildContext context) async => nextCode;
}

class FakeNotificationService implements NotificationService {
  final shown = <LowStockNotice>[];
  final _taps = StreamController<String>.broadcast();
  bool granted = true;
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<void> showLowStock(LowStockNotice notice) async => shown.add(notice);
  @override
  Stream<String> get taps => _taps.stream;
  void simulateTap(String route) => _taps.add(route);
}

class FakeFileService implements FileService {
  PickedFile? nextPick;
  final saved = <String, Uint8List>{};
  @override
  Future<PickedFile?> pick({List<String> extensions = const []}) async => nextPick;
  @override
  Future<bool> save(String fileName, Uint8List bytes, {required String mimeType}) async {
    saved[fileName] = bytes;
    return true;
  }
}
