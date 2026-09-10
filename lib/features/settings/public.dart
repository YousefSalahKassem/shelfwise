// OWNER: A1. Public surface of the settings feature (AGENT_PHASES §6).
//
// A1 owns the `settings` table. Other features that need to persist a small
// device-level value (e.g. A6's `last_backup_at`) read and write it through
// [SettingsRepository] instead of writing SQL against the table.
export 'data/settings_providers.dart' show settingsRepositoryProvider;
export 'domain/repositories/settings_repository.dart' show SettingKeys, SettingsRepository;
