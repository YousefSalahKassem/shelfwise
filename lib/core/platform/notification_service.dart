import 'package:meta/meta.dart';

import '../domain/stock_status.dart';

@immutable
class LowStockNotice {
  const LowStockNotice({
    required this.productId,
    required this.productName,
    required this.level,
    required this.quantityText,
  });
  final String productId;
  final String productName;

  /// [StockStatus.low] or [StockStatus.out].
  final StockStatus level;

  /// Already formatted for display, e.g. "2 kg".
  final String quantityText;
}

/// Local notifications (push/email come with W5).
abstract interface class NotificationService {
  /// Ask the OS/browser. On web call this only from a user tap.
  Future<bool> requestPermission();

  Future<void> showLowStock(LowStockNotice notice);

  /// Route to open when the user taps a notification (e.g. `/alerts`).
  Stream<String> get taps;
}
