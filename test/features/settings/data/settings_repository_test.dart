import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/brand/brand_providers.dart';
import 'package:shelfwise/core/database/app_database.dart';
import 'package:shelfwise/core/database/database_providers.dart';
import 'package:shelfwise/core/database/db_changes.dart';
import 'package:shelfwise/core/database/schema/tables.dart';
import 'package:shelfwise/core/settings/preferences_impl.dart';
import 'package:shelfwise/core/utils/clock.dart';
import 'package:shelfwise/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:shelfwise/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:shelfwise/features/settings/domain/repositories/settings_repository.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late DbChanges changes;
  late SettingsRepositoryImpl repository;

  setUp(() async {
    db = await openTestDatabase();
    changes = DbChanges();
    repository = SettingsRepositoryImpl(
      local: SettingsLocalDataSource(db: db, clock: FixedClock(Fixtures.now)),
      changes: changes,
    );
  });

  tearDown(() async {
    await changes.dispose();
    await db.close();
  });

  test('missing keys read as null and the store starts empty', () async {
    expect((await repository.read(SettingKeys.themeMode)).valueOrNull, isNull);
    expect((await repository.readAll()).valueOrNull, isEmpty);
  });

  test('writes, overwrites and reads values back', () async {
    await repository.write(SettingKeys.themeMode, 'dark');
    expect((await repository.read(SettingKeys.themeMode)).valueOrNull, 'dark');

    await repository.write(SettingKeys.themeMode, 'light');
    expect((await repository.read(SettingKeys.themeMode)).valueOrNull, 'light');
    expect((await db.db.query(T.settings)).length, 1, reason: 'one row per key');
  });

  test('remove soft-deletes so a later sync can replay it', () async {
    await repository.write(SettingKeys.locale, 'ar');
    await repository.remove(SettingKeys.locale);

    expect((await repository.read(SettingKeys.locale)).valueOrNull, isNull);
    expect((await repository.readAll()).valueOrNull, isEmpty);

    final row = (await db.db.query(T.settings)).single;
    expect(row['deleted_at'], isNotNull);
  });

  test('writing a removed key brings it back', () async {
    await repository.write(SettingKeys.locale, 'ar');
    await repository.remove(SettingKeys.locale);
    await repository.write(SettingKeys.locale, 'en');

    expect((await repository.read(SettingKeys.locale)).valueOrNull, 'en');
  });

  test('writes notify the settings table', () async {
    final tables = <Set<DbTable>>[];
    changes.watch({DbTable.settings}).listen(tables.add);

    await repository.write(SettingKeys.latinDigits, 'false');
    await pumpEventQueue();

    expect(tables.single, {DbTable.settings});
  });

  group('PreferencesController', () {
    ProviderContainer containerWith(AppDatabase database) {
      final container = ProviderContainer(
        overrides: [
          brandConfigProvider.overrideWithValue(Fixtures.brand()),
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('starts from the brand defaults', () async {
      final container = containerWith(db);
      final prefs = container.read(preferencesControllerProvider);

      expect(prefs.themeMode, ThemeMode.system);
      expect(prefs.locale, isNull);
      expect(prefs.latinDigits, isTrue);
      expect(prefs.autoLockMinutes, 5);
    });

    test('changes are written to the settings table and read back on the next run', () async {
      final first = containerWith(db);
      final controller = first.read(preferencesControllerProvider.notifier);
      await controller.restored;

      controller
        ..setThemeMode(ThemeMode.dark)
        ..setLocale(const Locale('ar'))
        ..setLatinDigits(false)
        ..setAutoLockMinutes(15);
      await pumpEventQueue();

      // A fresh container is the same device starting again.
      final second = containerWith(db);
      final restored = second.read(preferencesControllerProvider.notifier);
      await restored.restored;
      final prefs = second.read(preferencesControllerProvider);

      expect(prefs.themeMode, ThemeMode.dark);
      expect(prefs.locale, const Locale('ar'));
      expect(prefs.latinDigits, isFalse);
      expect(prefs.autoLockMinutes, 15);
    });

    test('clearing the language falls back to the profile/store/brand default', () async {
      final first = containerWith(db);
      final controller = first.read(preferencesControllerProvider.notifier);
      await controller.restored;
      controller.setLocale(const Locale('ar'));
      await pumpEventQueue();
      controller.setLocale(null);
      await pumpEventQueue();

      final second = containerWith(db);
      await second.read(preferencesControllerProvider.notifier).restored;
      expect(second.read(preferencesControllerProvider).locale, isNull);
    });

    test('auto-lock minutes never go negative', () async {
      final container = containerWith(db);
      container.read(preferencesControllerProvider.notifier).setAutoLockMinutes(-3);
      expect(container.read(preferencesControllerProvider).autoLockMinutes, 0);
    });

    test('without a database the preferences still work, in memory', () async {
      final container = ProviderContainer(
        overrides: [brandConfigProvider.overrideWithValue(Fixtures.brand())],
      );
      addTearDown(container.dispose);

      final controller = container.read(preferencesControllerProvider.notifier);
      await controller.restored;
      controller.setThemeMode(ThemeMode.dark);

      expect(container.read(preferencesControllerProvider).themeMode, ThemeMode.dark);
    });
  });
}
