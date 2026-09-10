// OWNER: A6.
import 'dart:convert';

import '../../database/app_database.dart';
import '../../database/db_changes.dart';
import '../../database/schema/tables.dart';
import '../../utils/clock.dart';
import '../../utils/ids.dart';
import '../analytics_service.dart';

/// Writes pilot events to `app_events` (TECHNICAL_STRUCTURE §11).
///
/// Two rules shape this class:
/// * **It must never throw into the UI.** A failed insert loses one metric;
///   it must not fail the stock movement that produced it.
/// * **It batches.** Events arrive in bursts (a CSV import logs one per row).
///   While a write is in flight the next events queue up and are inserted
///   together in one transaction.
class DbAnalyticsService implements AnalyticsService {
  DbAnalyticsService({
    required AppDatabase database,
    required Clock clock,
    required IdGenerator ids,
    required DbChanges changes,
    required String? Function() currentProfileId,
  })  : _database = database,
        _clock = clock,
        _ids = ids,
        _changes = changes,
        _currentProfileId = currentProfileId;

  final AppDatabase _database;
  final Clock _clock;
  final IdGenerator _ids;
  final DbChanges _changes;
  final String? Function() _currentProfileId;

  final List<Map<String, Object?>> _pending = [];
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> log(AppEvent event, [Map<String, Object?> props = const {}]) {
    try {
      final now = _clock.now().epochMs;
      _pending.add({
        C.id: _ids.newId(),
        'name': event.wireName,
        'props': props.isEmpty ? null : _encode(props),
        C.profileId: _currentProfileId(),
        C.createdAt: now,
        C.updatedAt: now,
      });
    } on Object {
      return Future<void>.value();
    }
    return _tail = _tail.then((_) => _write());
  }

  /// Completes when everything logged so far has been written (or dropped).
  Future<void> flush() => _tail;

  Future<void> _write() async {
    if (_pending.isEmpty) return;
    final rows = List.of(_pending);
    _pending.clear();
    try {
      await _database.transaction((txn) async {
        final batch = txn.batch();
        for (final row in rows) {
          batch.insert(T.appEvents, row);
        }
        await batch.commit(noResult: true);
      });
      _changes.notify({DbTable.appEvents});
    } on Object {
      // Metrics are best effort: a lost event must never surface as an error.
    }
  }

  /// Anything that isn't valid JSON (an entity, an enum) is stored as text
  /// rather than dropping the whole event.
  String _encode(Map<String, Object?> props) =>
      jsonEncode(props, toEncodable: (o) => o.toString());
}
