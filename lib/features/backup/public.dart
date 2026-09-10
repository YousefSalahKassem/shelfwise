// OWNER: A6. Public surface of the backup feature (AGENT_PHASES §6).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/auth/permission.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/route_paths.dart';
import '../../core/session/session_impl.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/core_providers.dart';
import 'data/datasources/storage_persistence.dart';
import 'presentation/backup_date.dart';
import 'presentation/providers/backup_providers.dart';

part 'public.g.dart';

/// A backup older than this is worth a nudge (the brief's rule).
const int backupReminderAfterDays = 7;

/// True when the last backup is older than 7 days (or there is none).
///
/// Never throws: on a screen without a database (widget tests) it is false.
@riverpod
Future<bool> backupReminder(Ref ref) async {
  if (!ref.watch(backupAvailableProvider)) return false;
  try {
    final last = await ref.watch(lastBackupProvider.future);
    if (last == null) return true;
    return daysBetween(last, ref.watch(clockProvider).now()) >= backupReminderAfterDays;
  } on Object {
    return false;
  }
}

/// Prompts the owner to protect the store's data. Place it on the dashboard
/// **unconditionally** (B1): it hides itself when there is nothing to say, and
/// it also carries the browser's "this data may be cleared" warning, which is
/// independent of [backupReminderProvider].
///
/// Staff never see it — only the owner can make a backup.
class BackupReminderBanner extends ConsumerWidget {
  const BackupReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(sessionControllerProvider).can(Permission.backupRestore)) {
      return const SizedBox.shrink();
    }

    final overdue = ref.watch(backupReminderProvider).valueOrNull ?? false;
    final storageDenied =
        ref.watch(storagePersistenceProvider).valueOrNull == StoragePersistence.denied;
    if (!overdue && !storageDenied) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final last = ref.watch(lastBackupProvider).valueOrNull;
    final days = last == null ? null : daysBetween(last, ref.watch(clockProvider).now());

    final title = storageDenied ? l10n.backup_storageWarningTitle : l10n.backup_reminderTitle;
    final message = storageDenied
        ? l10n.backup_storageWarningBody
        : days == null
            ? l10n.backup_reminderNever
            : l10n.backup_reminderStale(days);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: () => context.go(RoutePaths.settingsBackup),
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.backup_reminderAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
