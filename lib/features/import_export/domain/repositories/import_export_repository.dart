import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../../../../core/utils/date_range.dart';
import '../entities/import_models.dart';

abstract interface class ImportExportRepository {
  Future<Result<List<ImportRow>>> parse(Uint8List csvBytes);

  Future<Result<ImportPreview>> preview(List<ImportRow> rows, {bool updateExisting = false});

  Future<Result<ImportResult>> apply(ImportPreview preview);

  /// CSV bytes of the template with AR/EN headers.
  Uint8List template({required String languageCode});

  Future<Result<Uint8List>> exportProducts();

  Future<Result<Uint8List>> exportMovements(DateRange range);
}
