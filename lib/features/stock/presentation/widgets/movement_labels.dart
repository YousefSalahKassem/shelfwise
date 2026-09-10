// OWNER: A4. Translated labels and icons for movement types and units.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/money.dart' show normalizeDigits;
import '../../../../core/utils/quantity.dart';
import '../../domain/entities/stock.dart';

String unitLabel(AppLocalizations l10n, ProductUnit unit) => switch (unit) {
      ProductUnit.piece => l10n.stock_unitPiece,
      ProductUnit.kg => l10n.stock_unitKg,
      ProductUnit.g => l10n.stock_unitG,
      ProductUnit.l => l10n.stock_unitL,
      ProductUnit.ml => l10n.stock_unitMl,
      ProductUnit.box => l10n.stock_unitBox,
      ProductUnit.pack => l10n.stock_unitPack,
    };

String movementTypeLabel(AppLocalizations l10n, MovementType type) => switch (type) {
      MovementType.receive => l10n.stock_typeReceive,
      MovementType.sale => l10n.stock_typeSale,
      MovementType.damaged => l10n.stock_typeDamaged,
      MovementType.expired => l10n.stock_typeExpired,
      MovementType.adjustment => l10n.stock_typeAdjustment,
      MovementType.count => l10n.stock_typeCount,
      MovementType.transferIn => l10n.stock_typeTransferIn,
      MovementType.transferOut => l10n.stock_typeTransferOut,
    };

IconData movementTypeIcon(MovementType type) => switch (type) {
      MovementType.receive || MovementType.transferIn => Icons.arrow_downward,
      MovementType.sale => Icons.shopping_cart_outlined,
      MovementType.damaged => Icons.broken_image_outlined,
      MovementType.expired => Icons.schedule_outlined,
      MovementType.adjustment || MovementType.count => Icons.tune,
      MovementType.transferOut => Icons.arrow_upward,
    };

/// Date and time of a ledger row in the user's language, honouring the
/// Latin/Arabic-Indic digit preference (TECHNICAL_STRUCTURE §9).
String formatTimestamp(
  DateTime utc, {
  required String localeCode,
  required bool latinDigits,
}) {
  final text = DateFormat.MMMd(localeCode).add_jm().format(utc.toLocal());
  return latinDigits ? normalizeDigits(text) : text;
}

/// Types a store can pick in the quick-adjust screen (transfers come with D4,
/// stock count with D1).
const List<MovementType> adjustableTypes = [
  MovementType.receive,
  MovementType.sale,
  MovementType.damaged,
  MovementType.expired,
  MovementType.adjustment,
];
