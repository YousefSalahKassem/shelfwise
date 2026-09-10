import '../../../../core/database/schema/tables.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/pricing.dart';
import '../models/pricing_rows.dart';

/// `price_changes` row → [PriceChange]. Entities never carry column names.
PriceChange priceChangeFromRow(Map<String, Object?> row, String currency) => PriceChange(
      id: row[C.id]! as String,
      productId: row[C.productId]! as String,
      oldPrice: Money(row[PriceColumns.oldPriceMinor]! as int, currency),
      newPrice: Money(row[PriceColumns.newPriceMinor]! as int, currency),
      oldCost: _money(row[PriceColumns.oldCostMinor], currency),
      newCost: _money(row[PriceColumns.newCostMinor], currency),
      batchId: row[PriceColumns.batchId] as String?,
      profileId: row[C.profileId]! as String,
      createdAt: fromEpochMs(row[C.createdAt]! as int),
    );

Money? _money(Object? minor, String currency) =>
    minor == null ? null : Money(minor as int, currency);
