import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/platform/impl/files/platform_file_service.dart';
import 'package:shelfwise/core/platform/impl/scanner/platform_scanner_service.dart';

import '../../helpers/test_app.dart';

void main() {
  group('platform capabilities', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('the camera scanner covers Android, iOS and macOS', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(defaultSupportsCamera(), isTrue, reason: '$platform');
      }
    });

    test('Windows and Linux use the keyboard wedge instead', () {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(defaultSupportsCamera(), isFalse, reason: '$platform');
      }
    });

    test('the share sheet is only for phones', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(defaultUseShareSheet(), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(defaultUseShareSheet(), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(defaultUseShareSheet(), isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(defaultUseShareSheet(), isFalse);
    });
  });

  group('PlatformScannerService without a camera', () {
    testWidgets('falls back to the keyboard-wedge dialog', (tester) async {
      const service = PlatformScannerService(supportsCamera: false);
      expect(service.supportsCamera, isFalse);

      String? scanned;
      await pumpTestWidget(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async => scanned = await service.scan(context),
              child: const Text('scan'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), '6221031492025');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(scanned, '6221031492025');
    });
  });
}
