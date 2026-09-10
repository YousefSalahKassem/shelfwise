import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/platform/impl/scanner/keyboard_wedge_dialog.dart';

import '../../helpers/test_app.dart';

void main() {
  /// Opens the dialog the way a feature screen would and keeps the result.
  Future<List<String?>> openDialog(WidgetTester tester, {Locale? locale}) async {
    final results = <String?>[];
    await pumpTestWidget(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async => results.add(await showKeyboardWedgeDialog(context)),
            child: const Text('open'),
          ),
        ),
      ),
      locale: locale ?? const Locale('en'),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('a USB scanner types the code and presses Enter', (tester) async {
    final results = await openDialog(tester);

    await tester.enterText(find.byType(TextField), '6221031492025');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(results, ['6221031492025']);
  });

  testWidgets('the code can also be confirmed with the button', (tester) async {
    final results = await openDialog(tester);

    await tester.enterText(find.byType(TextField), ' 6221031492025 ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();

    expect(results, ['6221031492025'], reason: 'surrounding spaces are trimmed');
  });

  testWidgets('the confirm button stays disabled while the field is empty', (tester) async {
    await openDialog(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '123');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('cancelling returns null', (tester) async {
    final results = await openDialog(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('Arabic renders right-to-left but the code field stays LTR', (tester) async {
    await openDialog(tester, locale: const Locale('ar'));

    expect(find.text('امسح الباركود أو اكتبه'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(AlertDialog))), TextDirection.rtl);
    expect(tester.widget<TextField>(find.byType(TextField)).textDirection, TextDirection.ltr);
  });
}
