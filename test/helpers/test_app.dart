import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/brand/brand_config.dart';
import 'package:shelfwise/core/brand/brand_providers.dart';
import 'package:shelfwise/core/l10n/l10n.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_impl.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/core/theme/app_theme.dart';

import 'fixtures.dart';

/// Session controller that always returns [initial] (tests only).
class FixedSessionController extends SessionController {
  FixedSessionController(this.initial);
  final SessionState initial;
  @override
  SessionState build() => initial;
}

List<Override> baseOverrides({BrandConfig? brand, SessionState session = FakeSession.ownerSession}) => [
      brandConfigProvider.overrideWithValue(brand ?? Fixtures.brand()),
      sessionControllerProvider.overrideWith(() => FixedSessionController(session)),
    ];

/// Pumps [child] inside ProviderScope + MaterialApp with brand theme,
/// localizations and the given [locale] (Arabic → RTL).
Future<void> pumpTestWidget(
  WidgetTester tester,
  Widget child, {
  BrandConfig? brand,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  SessionState session = FakeSession.ownerSession,
  List<Override> overrides = const [],
}) async {
  final b = brand ?? Fixtures.brand();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...baseOverrides(brand: b, session: session), ...overrides],
      child: MaterialApp(
        theme: buildTheme(b, brightness),
        locale: locale,
        supportedLocales: b.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
