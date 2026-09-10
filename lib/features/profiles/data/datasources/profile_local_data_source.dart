import '../../../../core/auth/permission.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema/tables.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/services/pin_hasher.dart';

/// Stored PIN material. Never leaves the data layer (see [Profile]).
class PinCredentials {
  const PinCredentials({required this.hash, required this.salt});
  final String hash;
  final String salt;
}

/// The only place with SQL for `profiles`.
class ProfileLocalDataSource {
  ProfileLocalDataSource({
    required this.db,
    required this.clock,
    required this.ids,
    required this.hasher,
  });

  final AppDatabase db;
  final Clock clock;
  final IdGenerator ids;
  final PinHasher hasher;

  static const _columns = [C.id, C.storeId, 'name', 'role', 'locale', 'is_active'];

  Future<List<Profile>> findAll() async {
    final rows = await db.db.query(
      T.profiles,
      columns: _columns,
      where: '${C.deletedAt} IS NULL',
      orderBy: "role = 'owner' DESC, is_active DESC, ${C.createdAt} ASC",
    );
    return rows.map(_profile).toList();
  }

  Future<Profile?> findById(String id) async {
    final rows = await db.db.query(
      T.profiles,
      columns: _columns,
      where: '${C.id} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _profile(rows.first);
  }

  Future<PinCredentials?> findCredentials(String id) async {
    final rows = await db.db.query(
      T.profiles,
      columns: ['pin_hash', 'pin_salt'],
      where: '${C.id} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PinCredentials(hash: rows.first['pin_hash']! as String, salt: rows.first['pin_salt']! as String);
  }

  /// Active profiles with the given role, used for the staff limit.
  Future<int> countActive(Role role) async {
    final rows = await db.db.query(
      T.profiles,
      columns: ['COUNT(*) AS n'],
      where: 'role = ? AND is_active = 1 AND ${C.deletedAt} IS NULL',
      whereArgs: [role.name],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Id of the single store on this device, or null before onboarding.
  Future<String?> currentStoreId() async {
    final rows = await db.db.query(
      T.stores,
      columns: [C.id],
      where: '${C.deletedAt} IS NULL',
      orderBy: '${C.createdAt} ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[C.id] as String;
  }

  Future<Profile> insert({
    required String storeId,
    required String name,
    required Role role,
    required String pin,
    String? locale,
  }) async {
    final now = clock.now().epochMs;
    final salt = hasher.newSalt();
    final profile = Profile(id: ids.newId(), storeId: storeId, name: name, role: role, locale: locale);
    await db.transaction((txn) async {
      await txn.insert(T.profiles, {
        C.id: profile.id,
        C.storeId: storeId,
        'name': name,
        'role': role.name,
        'pin_hash': hasher.hash(pin, salt),
        'pin_salt': salt,
        'locale': locale,
        'is_active': 1,
        C.createdAt: now,
        C.updatedAt: now,
      });
    });
    return profile;
  }

  Future<void> updateDetails(Profile profile) async {
    final updated = await db.db.update(
      T.profiles,
      {
        'name': profile.name,
        'locale': profile.locale,
        'is_active': profile.isActive ? 1 : 0,
        C.updatedAt: clock.now().epochMs,
      },
      where: '${C.id} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [profile.id],
    );
    if (updated == 0) throw StateError('profile ${profile.id} not found');
  }

  Future<void> updatePin(String id, String pin) async {
    final salt = hasher.newSalt();
    final updated = await db.db.update(
      T.profiles,
      {'pin_hash': hasher.hash(pin, salt), 'pin_salt': salt, C.updatedAt: clock.now().epochMs},
      where: '${C.id} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [id],
    );
    if (updated == 0) throw StateError('profile $id not found');
  }

  /// Profiles are never deleted — stock movements reference them.
  Future<void> setActive(String id, {required bool active}) async {
    final updated = await db.db.update(
      T.profiles,
      {'is_active': active ? 1 : 0, C.updatedAt: clock.now().epochMs},
      where: '${C.id} = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [id],
    );
    if (updated == 0) throw StateError('profile $id not found');
  }

  static Profile _profile(Map<String, Object?> row) => Profile(
        id: row[C.id]! as String,
        storeId: row[C.storeId]! as String,
        name: row['name']! as String,
        role: Role.fromName(row['role']! as String),
        locale: row['locale'] as String?,
        isActive: (row['is_active']! as int) == 1,
      );
}
