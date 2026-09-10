// OWNER: A6.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/brand/brand_providers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/settings/preferences_impl.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../data/datasources/storage_persistence.dart';
import '../../domain/entities/backup_candidate.dart';
import '../backup_date.dart';
import '../backup_messages.dart';
import '../providers/backup_controller.dart';
import '../providers/backup_providers.dart';
import '../widgets/restore_summary_dialog.dart';

/// `/settings/backup` — the owner's safety net on a local-first app: make a
/// copy, put a copy back, and hand the pilot team the usage numbers.
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final task = ref.watch(backupControllerProvider);
    final busy = task != BackupTask.idle;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backup_title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _StoragePersistenceWarning(),
          _SectionCard(
            icon: Icons.save_outlined,
            title: l10n.backup_createTitle,
            body: l10n.backup_createBody,
            footer: const _LastBackupLine(),
            action: FilledButton.icon(
              onPressed: busy ? null : _createBackup,
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.backup_createAction),
            ),
            progress: task == BackupTask.creating ? l10n.backup_createWorking : null,
          ),
          _SectionCard(
            icon: Icons.settings_backup_restore,
            title: l10n.backup_restoreTitle,
            body: l10n.backup_restoreBody,
            action: OutlinedButton.icon(
              onPressed: busy ? null : _restore,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(l10n.backup_restoreAction),
            ),
            progress: switch (task) {
              BackupTask.restoring => l10n.backup_restoreWorking,
              BackupTask.choosing => l10n.common_loading,
              _ => null,
            },
          ),
          _SectionCard(
            icon: Icons.insights_outlined,
            title: l10n.backup_usageTitle,
            body: l10n.backup_usageBody,
            action: OutlinedButton.icon(
              onPressed: busy ? null : _exportUsage,
              icon: const Icon(Icons.table_chart_outlined),
              label: Text(l10n.backup_usageAction),
            ),
            progress: task == BackupTask.exporting ? l10n.common_loading : null,
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    final result = await ref.read(backupControllerProvider.notifier).createBackup();
    if (!mounted) return;
    final l10n = context.l10n;
    result.fold(
      (fileName) => _show(fileName == null ? l10n.backup_notSaved : l10n.backup_createdMessage(fileName)),
      _showFailure,
    );
  }

  Future<void> _exportUsage() async {
    final result = await ref.read(backupControllerProvider.notifier).exportUsage();
    if (!mounted) return;
    final l10n = context.l10n;
    result.fold(
      (fileName) => _show(fileName == null ? l10n.backup_notSaved : l10n.backup_usageExported(fileName)),
      _showFailure,
    );
  }

  /// Pick → summary → "replace everything?" → restore. Two confirmations,
  /// because this deletes data that has no other copy on the device.
  Future<void> _restore() async {
    final controller = ref.read(backupControllerProvider.notifier);
    final chosen = await controller.chooseBackup();
    if (!mounted) return;

    final BackupCandidate? candidate;
    switch (chosen) {
      case Err<BackupCandidate?>(:final failure):
        _showFailure(failure);
        return;
      case Success<BackupCandidate?>(:final value):
        candidate = value;
    }
    if (candidate == null) {
      _show(context.l10n.backup_restoreNoFile);
      return;
    }

    final wantsToContinue = await showRestoreSummaryDialog(context, candidate);
    if (!wantsToContinue || !mounted) return;

    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.backup_restoreFinalTitle,
      message: l10n.backup_restoreFinalBody,
      confirmLabel: l10n.backup_restoreFinalAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final restored = await controller.restore(candidate);
    if (!mounted) return;
    restored.fold(
      (_) {
        // Every profile id in the database has just been replaced: the session
        // must start again at the lock screen.
        ref.invalidate(sessionControllerProvider);
        _show(l10n.backup_restoreDone);
        context.go(RoutePaths.lock);
      },
      _showFailure,
    );
  }

  void _showFailure(Failure failure) {
    if (!mounted) return;
    _show(
      backupFailureMessage(
        context.l10n,
        failure,
        appName: ref.read(brandConfigProvider).appName,
      ),
    );
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Shown on the web when the browser refused persistent storage: the data can
/// then disappear when the device runs low on space (TECHNICAL_STRUCTURE §6).
class _StoragePersistenceWarning extends ConsumerWidget {
  const _StoragePersistenceWarning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final denied = ref.watch(storagePersistenceProvider).valueOrNull == StoragePersistence.denied;
    if (!denied) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_outlined, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.backup_storageWarningTitle,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.onErrorContainer),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.backup_storageWarningBody,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onErrorContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastBackupLine extends ConsumerWidget {
  const _LastBackupLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final last = ref.watch(lastBackupProvider).valueOrNull;
    final formatters = ref.watch(appFormattersProvider);
    final latinDigits = ref.watch(preferencesControllerProvider).latinDigits;
    final value = last == null
        ? l10n.backup_never
        : formatBackupTimestamp(
            last,
            languageCode: formatters.languageCode,
            latinDigits: latinDigits,
          );
    return Text(
      '${l10n.backup_lastBackupLabel}: $value',
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    this.footer,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget action;
  final Widget? footer;
  final String? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (footer != null) ...[const SizedBox(height: AppSpacing.sm), footer!],
            const SizedBox(height: AppSpacing.lg),
            Align(alignment: AlignmentDirectional.centerStart, child: action),
            if (progress != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const SizedBox(
                    height: AppSpacing.lg,
                    width: AppSpacing.lg,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(progress!, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
