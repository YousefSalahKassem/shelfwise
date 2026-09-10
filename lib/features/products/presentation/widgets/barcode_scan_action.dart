import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/platform/impl/platform_providers.dart';
import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';

/// Result of a scan started from the catalogue.
sealed class ScanOutcome {
  const ScanOutcome();
}

/// The scanned code belongs to [product].
class ScanFound extends ScanOutcome {
  const ScanFound(this.product);
  final Product product;
}

/// Nothing has this barcode yet — offer to create it.
class ScanUnknown extends ScanOutcome {
  const ScanUnknown(this.barcode);
  final String barcode;
}

/// Scanner closed without a code.
class ScanCancelled extends ScanOutcome {
  const ScanCancelled();
}

/// Opens the scanner (camera where available, keyboard wedge elsewhere) and
/// looks the code up. Returns [ScanCancelled] when the user backs out.
Future<ScanOutcome> scanAndFind(BuildContext context, WidgetRef ref) async {
  final code = await ref.read(scannerServiceProvider).scan(context);
  final barcode = code?.trim() ?? '';
  if (barcode.isEmpty) return const ScanCancelled();

  final result = await ref.read(findProductByBarcodeProvider)(barcode);
  return result.fold(
    (product) => product == null ? ScanUnknown(barcode) : ScanFound(product),
    (_) => ScanUnknown(barcode),
  );
}

/// App-bar / search-field button that starts a scan.
class BarcodeScanAction extends StatelessWidget {
  const BarcodeScanAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: context.l10n.catalogue_scan,
        icon: const Icon(Icons.qr_code_scanner),
      );
}
