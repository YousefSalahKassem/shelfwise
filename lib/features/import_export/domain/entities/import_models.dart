import 'package:freezed_annotation/freezed_annotation.dart';

part 'import_models.freezed.dart';

/// One parsed CSV line, raw strings (validated in preview).
@freezed
abstract class ImportRow with _$ImportRow {
  const factory ImportRow({
    required int line,
    required String name,
    String? nameAlt,
    String? category,
    String? subcategory,
    String? sku,
    String? barcode,
    String? unit,
    String? cost,
    String? price,
    String? quantity,
    String? reorderPoint,
  }) = _ImportRow;
}

@freezed
abstract class ImportRowError with _$ImportRowError {
  const factory ImportRowError({
    required int line,
    required String field,
    /// e.g. `required`, `invalid_number`, `duplicate_barcode`, `unknown_unit`.
    required String code,
  }) = _ImportRowError;
}

@freezed
abstract class ImportPreview with _$ImportPreview {
  const factory ImportPreview({
    required List<ImportRow> validRows,
    required List<ImportRowError> errors,
    required int toCreate,
    required int toUpdate,
    @Default(false) bool updateExisting,
  }) = _ImportPreview;
}

@freezed
abstract class ImportResult with _$ImportResult {
  const factory ImportResult({
    required int created,
    required int updated,
    required int skipped,
    required Duration duration,
  }) = _ImportResult;
}
