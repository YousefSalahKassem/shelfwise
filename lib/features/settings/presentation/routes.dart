// OWNER: A1. W0 stub with working theme/language/digits switches for gate G0.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission.dart';
import '../../../core/brand/brand_providers.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/session/session_impl.dart';
import '../../../core/settings/effective_locale.dart';
import '../../../core/settings/preferences_impl.dart';
import '../../../core/theme/spacing.dart';

FeatureRoutes get settingsRoutes => FeatureRoutes(
      shell: [
        GoRoute(path: RoutePaths.settings, builder: (context, state) => const _SettingsStubPage()),
      ],
    );

class _SettingsStubPage extends ConsumerWidget {
  const _SettingsStubPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(preferencesControllerProvider);
    final controller = ref.read(preferencesControllerProvider.notifier);
    final locale = ref.watch(effectiveLocaleProvider);
    final brand = ref.watch(brandConfigProvider);
    final session = ref.watch(sessionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.settings_theme, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l10n.common_themeSystem)),
              ButtonSegment(value: ThemeMode.light, label: Text(l10n.common_themeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.common_themeDark)),
            ],
            selected: {prefs.themeMode},
            onSelectionChanged: (s) => controller.setThemeMode(s.first),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.settings_language, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: [
              for (final l in brand.supportedLocales)
                ButtonSegment(
                  value: l.languageCode,
                  label: Text(l.languageCode == 'ar' ? l10n.common_languageArabic : l10n.common_languageEnglish),
                ),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (s) => controller.setLocale(Locale(s.first)),
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settings_latinDigits),
            value: prefs.latinDigits,
            onChanged: controller.setLatinDigits,
          ),
          const Divider(height: AppSpacing.xxl),
          if (session.can(Permission.manageProfiles))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people_outline),
              title: Text(l10n.settings_profiles),
              onTap: () => context.go(RoutePaths.settingsProfiles),
            ),
          if (session.can(Permission.importExport))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l10n.settings_import),
              onTap: () => context.go(RoutePaths.settingsImport),
            ),
          if (session.can(Permission.backupRestore))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.backup_outlined),
              title: Text(l10n.settings_backup),
              onTap: () => context.go(RoutePaths.settingsBackup),
            ),
        ],
      ),
    );
  }
}
