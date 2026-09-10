import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permission.dart';
import '../../../../core/brand/brand_config.dart';
import '../../../../core/brand/brand_providers.dart';
import '../../../../core/brand/tier.dart';
import '../../../../core/error/result.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/settings/preferences_impl.dart';
import '../../../../core/theme/spacing.dart';
import '../../../onboarding/data/store_providers.dart';

/// Appearance, language, security and store details (`/settings`).
/// Staff see only the appearance section; the rest is owner-only.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const autoLockChoices = [0, 1, 5, 15, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
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
          _Section(label: l10n.settings_appearance),
          Text(l10n.settings_theme, style: theme.textTheme.titleSmall),
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
          Text(l10n.settings_language, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: [
              for (final l in brand.supportedLocales)
                ButtonSegment(
                  value: l.languageCode,
                  label: Text(
                    l.languageCode == 'ar'
                        ? l10n.common_languageArabic
                        : l10n.common_languageEnglish,
                  ),
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

          _Section(label: l10n.settings_security),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_clock_outlined),
            title: Text(l10n.settings_autoLock),
            trailing: DropdownButton<int>(
              value: autoLockChoices.contains(prefs.autoLockMinutes)
                  ? prefs.autoLockMinutes
                  : autoLockChoices.last,
              onChanged: session.can(Permission.manageSettings)
                  ? (value) => controller.setAutoLockMinutes(value ?? 0)
                  : null,
              items: [
                for (final minutes in autoLockChoices)
                  DropdownMenuItem(
                    value: minutes,
                    child: Text(
                      minutes == 0
                          ? l10n.settings_autoLockNever
                          : l10n.settings_autoLockAfter(minutes),
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.profiles_lockNow),
            onTap: ref.read(sessionControllerProvider.notifier).lock,
          ),
          if (session.can(Permission.manageProfiles))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people_outline),
              title: Text(l10n.settings_profiles),
              onTap: () => context.go(RoutePaths.settingsProfiles),
            ),

          if (session.can(Permission.manageSettings)) ...[
            _Section(label: l10n.settings_store),
            const _StoreDetailsForm(),
          ],

          if (session.can(Permission.importExport) || session.can(Permission.backupRestore))
            _Section(label: l10n.settings_data),
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

          _Section(label: l10n.settings_about),
          const _AboutBrand(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: AppSpacing.xl),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      );
}

/// Store name and currency — owner only, enforced again in `UpdateStore`.
class _StoreDetailsForm extends ConsumerStatefulWidget {
  const _StoreDetailsForm();

  @override
  ConsumerState<_StoreDetailsForm> createState() => _StoreDetailsFormState();
}

class _StoreDetailsFormState extends ConsumerState<_StoreDetailsForm> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(sessionControllerProvider).store?.name ?? '',
  );
  late String _currency =
      ref.read(sessionControllerProvider).store?.currency ?? BrandConfig.supportedCurrencies.first;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(updateStoreProvider)(name: _name.text, currency: _currency);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Success(:final value):
        ref.read(sessionControllerProvider.notifier).applyStore(value);
        messenger.showSnackBar(SnackBar(content: Text(l10n.settings_storeSaved)));
      case Err(:final failure):
        setState(() => _error = failureMessage(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currencies = BrandConfig.supportedCurrencies.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: l10n.settings_storeName, errorText: _error),
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<String>(
          initialValue: currencies.contains(_currency) ? _currency : currencies.first,
          decoration: InputDecoration(
            labelText: l10n.settings_currency,
            helperText: l10n.settings_currencyNote,
            helperMaxLines: 2,
          ),
          items: [for (final c in currencies) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (value) => setState(() => _currency = value ?? _currency),
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(l10n.settings_saveStore),
          ),
        ),
      ],
    );
  }
}

/// Brand name, plan and the support contacts from `brand.json`.
class _AboutBrand extends ConsumerWidget {
  const _AboutBrand();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = ref.watch(brandConfigProvider);
    final support = brand.support;

    Widget contact(IconData icon, String title, String value) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(value, textDirection: TextDirection.ltr),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.settings_copiedContact(value))));
          },
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storefront_outlined),
          title: Text(brand.appName),
          subtitle: brand.companyName == null ? null : Text(brand.companyName!),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.workspace_premium_outlined),
          title: Text(l10n.settings_plan),
          subtitle: Text(switch (brand.tier) {
            Tier.shelf => l10n.settings_planShelf,
            Tier.aisle => l10n.settings_planAisle,
            Tier.chain => l10n.settings_planChain,
          }),
        ),
        if (support.phone != null)
          contact(Icons.call_outlined, l10n.settings_supportPhone, support.phone!),
        if (support.whatsapp != null)
          contact(Icons.chat_outlined, l10n.settings_supportWhatsapp, support.whatsapp!),
        if (support.email != null)
          contact(Icons.mail_outline, l10n.settings_supportEmail, support.email!),
        if (brand.privacyUrl != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.policy_outlined),
            title: Text(l10n.settings_privacy),
            subtitle: Text(brand.privacyUrl!, textDirection: TextDirection.ltr),
          ),
      ],
    );
  }
}
