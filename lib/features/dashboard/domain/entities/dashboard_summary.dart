import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/money.dart';

part 'dashboard_summary.freezed.dart';

enum RecentChangeKind { movement, priceBatch }

@freezed
abstract class RecentChange with _$RecentChange {
  const factory RecentChange({
    required RecentChangeKind kind,
    /// Movement type name or batch size, rendered by the UI.
    required String title,
    String? productId,
    String? profileName,
    required DateTime at,
  }) = _RecentChange;
}

@freezed
abstract class DashboardSummary with _$DashboardSummary {
  const factory DashboardSummary({
    required int productCount,
    required int lowCount,
    required int outCount,
    required Money stockValueCost,
    required Money stockValueRetail,
    @Default(<RecentChange>[]) List<RecentChange> recent,
  }) = _DashboardSummary;
}
