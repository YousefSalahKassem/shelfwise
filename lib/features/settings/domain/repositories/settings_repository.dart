import '../../../../core/error/result.dart';

/// Keys stored in the `settings` table. A1 owns the table; other features that
/// need a small persisted value use `settingsStoreProvider` from
/// `features/settings/public.dart` and add their key here via a change request.
abstract final class SettingKeys {
  static const themeMode = 'theme_mode';
  static const locale = 'locale';
  static const latinDigits = 'latin_digits';
  static const autoLockMinutes = 'auto_lock_minutes';

  /// Written by A6 (backup) through the public settings store.
  static const lastBackupAt = 'last_backup_at';
}

/// Small key/value store on the device (TECHNICAL_STRUCTURE §6, `settings`).
abstract interface class SettingsRepository {
  Future<Result<Map<String, String>>> readAll();

  Future<Result<String?>> read(String key);

  Future<Result<void>> write(String key, String value);

  Future<Result<void>> remove(String key);
}
