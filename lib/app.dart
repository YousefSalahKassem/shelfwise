import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/brand/brand_providers.dart';
import 'core/l10n/l10n.dart';
import 'core/router/app_router.dart';
import 'core/settings/effective_locale.dart';
import 'core/settings/preferences_impl.dart';
import 'core/theme/app_theme.dart';

class ShelfWiseApp extends ConsumerWidget {
  const ShelfWiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandConfigProvider);
    final prefs = ref.watch(preferencesControllerProvider);
    final locale = ref.watch(effectiveLocaleProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: brand.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brand, Brightness.light),
      darkTheme: buildTheme(brand, Brightness.dark),
      themeMode: prefs.themeMode,
      locale: locale,
      supportedLocales: brand.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
