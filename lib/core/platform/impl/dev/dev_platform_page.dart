// OWNER: A5. Debug-only page to try the three platform services by hand.
// Reachable at /dev/platform; the router blocks it in release builds.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/stock_status.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/spacing.dart';
import '../../notification_service.dart';
import '../platform_providers.dart';

class DevPlatformPage extends ConsumerStatefulWidget {
  const DevPlatformPage({super.key});

  @override
  ConsumerState<DevPlatformPage> createState() => _DevPlatformPageState();
}

class _DevPlatformPageState extends ConsumerState<DevPlatformPage> {
  String? _result;

  void _show(String message) {
    if (mounted) setState(() => _result = message);
  }

  Future<void> _run(AppLocalizations l10n, Future<String> Function() action) async {
    try {
      _show(await action());
    } on Object catch (error) {
      _show(l10n.platform_devFailed('$error'));
    }
  }

  Future<void> _scan() async {
    final l10n = context.l10n;
    final code = await ref.read(scannerServiceProvider).scan(context);
    _show(code == null ? l10n.platform_devCancelled : l10n.platform_devScanned(code));
  }

  Future<void> _requestPermission() {
    final l10n = context.l10n;
    return _run(l10n, () async {
      final granted = await ref.read(notificationServiceProvider).requestPermission();
      return granted ? l10n.platform_devPermissionGranted : l10n.platform_devPermissionDenied;
    });
  }

  Future<void> _notify(StockStatus level) {
    final l10n = context.l10n;
    return _run(l10n, () async {
      await ref.read(notificationServiceProvider).showLowStock(
            LowStockNotice(
              productId: 'dev-product',
              productName: 'Dev product',
              level: level,
              quantityText: level == StockStatus.out ? '0' : '2',
            ),
          );
      return l10n.platform_devNotificationSent;
    });
  }

  Future<void> _pick() {
    final l10n = context.l10n;
    return _run(l10n, () async {
      final file = await ref.read(fileServiceProvider).pick();
      return file == null
          ? l10n.platform_devCancelled
          : l10n.platform_devPicked(file.name, '${file.bytes.length}');
    });
  }

  Future<void> _save() {
    final l10n = context.l10n;
    return _run(l10n, () async {
      final bytes = Uint8List.fromList(utf8.encode('ShelfWise platform check\n'));
      final saved = await ref
          .read(fileServiceProvider)
          .save('shelfwise-check.txt', bytes, mimeType: 'text/plain');
      return saved ? l10n.platform_devSaved : l10n.platform_devCancelled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scanner = ref.watch(scannerServiceProvider);
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.common_devPlatform)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.platform_devPlatformLabel(platform), style: theme.textTheme.bodyMedium),
          const Divider(height: AppSpacing.xxl),
          Text(l10n.platform_devScannerSection, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            scanner.supportsCamera
                ? l10n.platform_devCameraAvailable
                : l10n.platform_devCameraUnavailable,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            label: Text(l10n.platform_devScan),
          ),
          const Divider(height: AppSpacing.xxl),
          Text(l10n.platform_devNotificationsSection, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.tonalIcon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.lock_open_outlined),
                label: Text(l10n.platform_devRequestPermission),
              ),
              OutlinedButton(
                onPressed: () => _notify(StockStatus.low),
                child: Text(l10n.platform_devShowLow),
              ),
              OutlinedButton(
                onPressed: () => _notify(StockStatus.out),
                child: Text(l10n.platform_devShowOut),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xxl),
          Text(l10n.platform_devFilesSection, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.tonalIcon(
                onPressed: _pick,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(l10n.platform_devPick),
              ),
              FilledButton.tonalIcon(
                onPressed: _save,
                icon: const Icon(Icons.save_alt_outlined),
                label: Text(l10n.platform_devSave),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xxl),
          Text(l10n.platform_devResult, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(_result ?? l10n.platform_devNoResult),
        ],
      ),
    );
  }
}
