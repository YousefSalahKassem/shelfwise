import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_info.freezed.dart';

@freezed
abstract class BackupInfo with _$BackupInfo {
  const factory BackupInfo({
    required int schemaVersion,
    required String brandId,
    required String storeId,
    required String storeName,
    required DateTime createdAt,
    required Map<String, int> tableCounts,
  }) = _BackupInfo;
}
