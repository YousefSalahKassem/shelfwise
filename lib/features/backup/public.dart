// OWNER: A6. Public surface of the backup feature.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'public.g.dart';

/// True when the last backup is older than 7 days (or never). W0: always false.
@riverpod
Future<bool> backupReminder(Ref ref) async => false;

/// Dashboard banner prompting a backup (placed by B1).
class BackupReminderBanner extends ConsumerWidget {
  const BackupReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}
