import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'schema/tables.dart';

part 'db_changes.g.dart';

/// Tables that can change. Repositories call [DbChanges.notify] after every
/// committed write; query providers watch the tables they read.
enum DbTable {
  stores(T.stores),
  branches(T.branches),
  profiles(T.profiles),
  categories(T.categories),
  products(T.products),
  productImages(T.productImages),
  stockLevels(T.stockLevels),
  stockMovements(T.stockMovements),
  priceChanges(T.priceChanges),
  stockAlerts(T.stockAlerts),
  appEvents(T.appEvents),
  settings(T.settings);

  const DbTable(this.tableName);
  final String tableName;
}

class DbChanges {
  final _controller = StreamController<Set<DbTable>>.broadcast();

  /// Call after a transaction commits.
  void notify(Set<DbTable> tables) {
    if (tables.isNotEmpty) _controller.add(Set.unmodifiable(tables));
  }

  /// Emits whenever any of [tables] changes.
  Stream<Set<DbTable>> watch(Set<DbTable> tables) =>
      _controller.stream.where((changed) => changed.any(tables.contains));

  Future<void> dispose() => _controller.close();
}

@Riverpod(keepAlive: true)
DbChanges dbChanges(Ref ref) {
  final changes = DbChanges();
  ref.onDispose(changes.dispose);
  return changes;
}

/// Helper for query providers: emits [query] once, then again after each
/// change to [tables].
Stream<R> watchQuery<R>(DbChanges changes, Set<DbTable> tables, Future<R> Function() query) async* {
  yield await query();
  await for (final _ in changes.watch(tables)) {
    yield await query();
  }
}
