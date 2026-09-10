import '../../../../core/auth/permission.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema/tables.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/ids.dart';
import '../../../profiles/domain/services/pin_hasher.dart';

/// The only place with SQL for `stores` and `branches` (and for the owner row
/// of `profiles`, which onboarding writes in the same transaction).
class StoreLocalDataSource {
  StoreLocalDataSource({
    required this.db,
    required this.clock,
    required this.ids,
    required this.hasher,
  });

  final AppDatabase db;
  final Clock clock;
  final IdGenerator ids;
  final PinHasher hasher;

  /// The single store of this device, or null before onboarding.
  Future<Store?> findStore() async {
    final rows = await db.db.query(
      T.stores,
      where: '${C.deletedAt} IS NULL',
      orderBy: '${C.createdAt} ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : _store(rows.first);
  }

  Future<Branch?> findDefaultBranch(String storeId) async {
    final rows = await db.db.query(
      T.branches,
      where: '${C.storeId} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [storeId],
      orderBy: 'is_default DESC, ${C.createdAt} ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : _branch(rows.first);
  }

  /// Store + default branch + owner profile, in one transaction.
  Future<(Store, Branch, Profile)> createStoreWithOwner({
    required String storeName,
    required String currency,
    required String locale,
    required String ownerName,
    required String pin,
  }) async {
    final now = clock.now().epochMs;
    final audit = {C.createdAt: now, C.updatedAt: now};
    final store = Store(
      id: ids.newId(),
      name: storeName,
      currency: currency,
      locale: locale,
    );
    final branch = Branch(
      id: ids.newId(),
      storeId: store.id,
      name: storeName,
      isDefault: true,
    );
    final owner = Profile(
      id: ids.newId(),
      storeId: store.id,
      name: ownerName,
      role: Role.owner,
      locale: locale,
    );
    final salt = hasher.newSalt();
    final hash = hasher.hash(pin, salt);

    await db.transaction((txn) async {
      await txn.insert(T.stores, {
        C.id: store.id,
        'name': store.name,
        'currency': store.currency,
        'locale': store.locale,
        ...audit,
      });
      await txn.insert(T.branches, {
        C.id: branch.id,
        C.storeId: store.id,
        'name': branch.name,
        'is_default': 1,
        ...audit,
      });
      await txn.insert(T.profiles, {
        C.id: owner.id,
        C.storeId: store.id,
        'name': owner.name,
        'role': Role.owner.name,
        'pin_hash': hash,
        'pin_salt': salt,
        'locale': owner.locale,
        'is_active': 1,
        ...audit,
      });
    });
    return (store, branch, owner);
  }

  Future<Store> updateStore({
    required String id,
    required String name,
    required String currency,
  }) async {
    final updated = await db.db.update(
      T.stores,
      {'name': name, 'currency': currency, C.updatedAt: clock.now().epochMs},
      where: '${C.id} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [id],
    );
    if (updated == 0) throw StateError('store $id not found');
    return (await findStore())!;
  }

  static Store _store(Map<String, Object?> row) => Store(
    id: row[C.id]! as String,
    name: row['name']! as String,
    currency: row['currency']! as String,
    locale: row['locale']! as String,
  );

  static Branch _branch(Map<String, Object?> row) => Branch(
    id: row[C.id]! as String,
    storeId: row[C.storeId]! as String,
    name: row['name']! as String,
    isDefault: (row['is_default']! as int) == 1,
  );
}
