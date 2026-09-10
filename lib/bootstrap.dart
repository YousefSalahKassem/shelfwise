import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/brand/brand_config.dart';
import 'core/brand/brand_loader.dart';
import 'core/brand/brand_providers.dart';
import 'core/config/env.dart';
import 'core/database/app_database.dart';
import 'core/database/database_providers.dart';
import 'core/database/db_factory.dart';

/// Loads the brand, opens the database and starts the app.
/// Feature implementations plug in through their own providers
/// (session_impl, preferences_impl, platform_providers, analytics_impl) —
/// nobody needs to edit this file.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final BrandConfig brand;
  try {
    brand = await BrandLoader(rootBundle).load(Env.brandId);
  } on Object catch (e) {
    runApp(_FatalErrorApp(message: 'Brand "${Env.brandId}" could not be loaded.\n\n$e'));
    return;
  }

  final AppDatabase database;
  try {
    final factory = await createDatabaseFactory();
    final path = await databasePath('shelfwise_${brand.id}.db');
    database = await AppDatabase.open(factory: factory, path: path);
  } on Object catch (e) {
    runApp(_FatalErrorApp(message: 'The local database could not be opened.\n\n$e'));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        brandConfigProvider.overrideWithValue(brand),
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const ShelfWiseApp(),
    ),
  );
}

/// Shown only for configuration errors that must be fixed by the team.
class _FatalErrorApp extends StatelessWidget {
  const _FatalErrorApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      );
}
