// OWNER: A6.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/settings/preferences_impl.dart';
import '../../../../core/theme/spacing.dart';
import '../../domain/entities/backup_candidate.dart';
import '../backup_date.dart';
import '../backup_messages.dart';

/// First of the two confirmations: what this file holds, before anything is
/// deleted. Returns true if the owner wants to continue.
Future<bool> showRestoreSummaryDialog(BuildContext context, BackupCandidate candidate) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _RestoreSummaryDialog(candidate: candidate),
  );
  return result ?? false;
}

class _RestoreSummaryDialog extends ConsumerWidget {
  const _RestoreSummaryDialog({required this.candidate});

  final BackupCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final prefs = ref.watch(preferencesControllerProvider);
    final info = candidate.info;
    final counts = info.tableCounts.entries.where((e) => e.value > 0).toList();

    return AlertDialog(
      title: Text(l10n.backup_restoreSummaryTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(candidate.fileName, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            if (info.storeName.isNotEmpty) Text(l10n.backup_restoreSummaryStore(info.storeName)),
            Text(
              l10n.backup_restoreSummaryCreated(
                formatBackupTimestamp(
                  info.createdAt,
                  languageCode: formatters.languageCode,
                  latinDigits: prefs.latinDigits,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.backup_restoreSummaryContents, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            for (final entry in counts)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
                child: Text(
                  l10n.backup_restoreSummaryRow(
                    backupTableLabel(l10n, entry.key),
                    formatters.number(entry.value),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.backup_restoreWarning,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.backup_restoreContinue),
        ),
      ],
    );
  }
}
