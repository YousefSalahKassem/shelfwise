import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/platform/fakes.dart';
import 'package:shelfwise/core/platform/impl/dev/dev_platform_page.dart';
import 'package:shelfwise/core/platform/impl/platform_providers.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('the dev page drives all three services through their providers', (tester) async {
    // Tall enough that every section fits without scrolling.
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final scanner = FakeScannerService(nextCode: '6221031492025');
    final notifications = FakeNotificationService();
    final files = FakeFileService();

    await pumpTestWidget(
      tester,
      const DevPlatformPage(),
      overrides: [
        scannerServiceProvider.overrideWithValue(scanner),
        notificationServiceProvider.overrideWithValue(notifications),
        fileServiceProvider.overrideWithValue(files),
      ],
    );

    expect(find.text('Nothing yet'), findsOneWidget);

    await tester.tap(find.text('Scan a barcode'));
    await tester.pumpAndSettle();
    expect(find.text('Scanned: 6221031492025'), findsOneWidget);

    await tester.tap(find.text('Show a low-stock notification'));
    await tester.pumpAndSettle();
    expect(notifications.shown, hasLength(1));

    await tester.tap(find.text('Save a test file'));
    await tester.pumpAndSettle();
    expect(files.saved.keys, ['shelfwise-check.txt']);
    expect(find.text('Saved'), findsOneWidget);
  });
}
