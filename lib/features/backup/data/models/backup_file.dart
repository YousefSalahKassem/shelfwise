// OWNER: A6.
import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/database/schema/tables.dart';
import '../../domain/entities/backup_info.dart';
import 'backup_tables.dart';

/// A backup file could not be read. [code] is matched to a message by the UI
/// (see `backupFailureMessage`), so it is part of this feature's contract.
class BackupFormatException implements Exception {
  const BackupFormatException(this.code, [this.detail]);

  /// `not_backup` (wrong kind of file) or `corrupt` (right kind, damaged).
  final String code;
  final String? detail;

  @override
  String toString() => 'BackupFormatException($code${detail == null ? '' : ': $detail'})';
}

/// The on-disk shape of a backup: a header plus every table's rows.
///
/// Blobs (product thumbnails) become `{"__blob__": "<base64>"}` so the whole
/// file stays valid JSON and survives being e-mailed or put in cloud storage.
class BackupFile {
  const BackupFile({
    required this.schemaVersion,
    required this.brandId,
    required this.storeId,
    required this.storeName,
    required this.createdAt,
    required this.tables,
  });

  /// Identifies our files among the JSON the user may pick.
  static const formatMarker = 'shelfwise.backup';

  /// Envelope version — bumped only if the file *layout* changes.
  /// The database schema has its own [schemaVersion].
  static const fileVersion = 1;

  static const blobKey = '__blob__';

  final int schemaVersion;
  final String brandId;
  final String storeId;
  final String storeName;
  final DateTime createdAt;
  final Map<String, List<Map<String, Object?>>> tables;

  BackupInfo get info => BackupInfo(
        schemaVersion: schemaVersion,
        brandId: brandId,
        storeId: storeId,
        storeName: storeName,
        createdAt: createdAt,
        tableCounts: {for (final e in tables.entries) e.key: e.value.length},
      );

  Uint8List encode() {
    final json = <String, Object?>{
      'format': formatMarker,
      'fileVersion': fileVersion,
      'schemaVersion': schemaVersion,
      'brandId': brandId,
      'storeId': storeId,
      'storeName': storeName,
      'createdAt': createdAt.toUtc().toIso8601String(),
      // Repeated in the header so a truncated file can be spotted before it is
      // restored, and so the summary can be shown without walking every row.
      'tableCounts': {for (final e in tables.entries) e.key: e.value.length},
      'tables': {
        for (final e in tables.entries) e.key: [for (final row in e.value) _encodeRow(row)],
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  /// Reads [bytes] without touching the database.
  /// Throws [BackupFormatException] for anything that isn't a readable backup.
  static BackupFile parse(Uint8List bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const BackupFormatException('not_backup', 'not utf-8');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      // A file that names itself a ShelfWise backup but won't parse is a
      // damaged backup, not somebody's holiday photo.
      throw BackupFormatException(
        text.contains(formatMarker) ? 'corrupt' : 'not_backup',
        e.message,
      );
    }

    if (decoded is! Map || decoded['format'] != formatMarker) {
      throw const BackupFormatException('not_backup');
    }
    final json = decoded.cast<String, Object?>();

    final schemaVersion = json['schemaVersion'];
    final brandId = json['brandId'];
    final storeId = json['storeId'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (schemaVersion is! int || brandId is! String || storeId is! String || createdAt == null) {
      throw const BackupFormatException('corrupt', 'header');
    }

    final rawTables = json['tables'];
    if (rawTables is! Map) throw const BackupFormatException('corrupt', 'tables');

    final tables = <String, List<Map<String, Object?>>>{};
    rawTables.forEach((name, value) {
      if (name is! String || !BackupTables.known.contains(name)) {
        throw BackupFormatException('corrupt', 'unknown table "$name"');
      }
      if (value is! List) throw BackupFormatException('corrupt', 'table "$name"');
      tables[name] = [
        for (final row in value)
          if (row is Map)
            _decodeRow(row.cast<String, Object?>())
          else
            throw BackupFormatException('corrupt', 'row in "$name"'),
      ];
    });

    // Truncated or hand-edited files are rejected before anything is deleted.
    final counts = json['tableCounts'];
    if (counts is Map) {
      counts.forEach((name, expected) {
        final actual = tables[name]?.length ?? 0;
        if (expected is int && expected != actual) {
          throw BackupFormatException('corrupt', '"$name": $actual of $expected rows');
        }
      });
    }

    return BackupFile(
      schemaVersion: schemaVersion,
      brandId: brandId,
      storeId: storeId,
      storeName: json['storeName'] is String ? json['storeName']! as String : '',
      createdAt: createdAt,
      tables: tables,
    );
  }

  /// Drops columns this build's schema doesn't have. Restoring an older backup
  /// then relies on the new columns' defaults; a migration that adds a column
  /// needing real data must add a step to [BackupUpgrades].
  BackupFile withColumns(Map<String, Set<String>> liveColumns) => BackupFile(
        schemaVersion: schemaVersion,
        brandId: brandId,
        storeId: storeId,
        storeName: storeName,
        createdAt: createdAt,
        tables: {
          for (final e in tables.entries)
            e.key: [
              for (final row in e.value)
                {
                  for (final c in row.entries)
                    if (liveColumns[e.key]?.contains(c.key) ?? false) c.key: c.value,
                },
            ],
        },
      );

  static Map<String, Object?> _encodeRow(Map<String, Object?> row) => {
        for (final e in row.entries)
          e.key: e.value is Uint8List
              ? {blobKey: base64Encode(e.value! as Uint8List)}
              : e.value is List<int>
                  ? {blobKey: base64Encode(e.value! as List<int>)}
                  : e.value,
      };

  static Map<String, Object?> _decodeRow(Map<String, Object?> row) => {
        for (final e in row.entries) e.key: _decodeValue(e.key, e.value),
      };

  static Object? _decodeValue(String column, Object? value) {
    if (value is Map && value.containsKey(blobKey)) {
      try {
        return base64Decode('${value[blobKey]}');
      } on FormatException {
        throw BackupFormatException('corrupt', 'blob in "$column"');
      }
    }
    if (value == null || value is String || value is num || value is bool) return value;
    throw BackupFormatException('corrupt', 'value in "$column"');
  }
}

/// Data fix-ups needed when a backup from an older schema is restored.
///
/// Empty at schema v1. When migration `mNNN` adds a column that old rows can't
/// leave at its default, add a step here with `toVersion: NNN`; [BackupUpgrades.apply]
/// runs every step above the file's version, in order.
abstract final class BackupUpgrades {
  static const steps = <BackupUpgrade>[];

  static Map<String, List<Map<String, Object?>>> apply(
    Map<String, List<Map<String, Object?>>> tables,
    int fromVersion,
  ) {
    var current = tables;
    for (final step in steps.where((s) => s.toVersion > fromVersion)) {
      current = step.upgrade(current);
    }
    return current;
  }
}

abstract class BackupUpgrade {
  const BackupUpgrade();
  int get toVersion;
  Map<String, List<Map<String, Object?>>> upgrade(Map<String, List<Map<String, Object?>>> tables);
}

/// Rows whose foreign keys point inside their own table must be inserted after
/// their parent. Only `categories` does this (a sub-category has a parent).
List<Map<String, Object?>> orderedForInsert(String table, List<Map<String, Object?>> rows) {
  if (table != T.categories) return rows;
  return [
    ...rows.where((r) => r['parent_id'] == null),
    ...rows.where((r) => r['parent_id'] != null),
  ];
}
