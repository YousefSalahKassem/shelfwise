import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/brand/brand_providers.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/db_changes.dart';
import '../../../core/session/session_impl.dart';
import '../../../core/session/session_reader.dart';
import '../../../core/utils/core_providers.dart';
import '../../onboarding/data/store_providers.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/usecases/manage_profiles.dart';
import '../domain/usecases/unlock_profile.dart';
import 'datasources/profile_local_data_source.dart';
import 'repositories/profile_repository_impl.dart';

part 'profile_providers.g.dart';

@Riverpod(keepAlive: true)
ProfileLocalDataSource profileLocalDataSource(Ref ref) => ProfileLocalDataSource(
      db: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
      ids: ref.watch(idGeneratorProvider),
      hasher: pinHasher,
    );

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) => ProfileRepositoryImpl(
      local: ref.watch(profileLocalDataSourceProvider),
      changes: ref.watch(dbChangesProvider),
    );

/// Kept alive so the wrong-PIN cooldown survives navigation.
@Riverpod(keepAlive: true)
UnlockProfile unlockProfile(Ref ref) => UnlockProfile(
      repository: ref.watch(profileRepositoryProvider),
      analytics: ref.watch(analyticsServiceProvider),
      clock: ref.watch(clockProvider),
    );

@riverpod
CreateStaffProfile createStaffProfile(Ref ref) => CreateStaffProfile(
      repository: ref.watch(profileRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
      flags: ref.watch(featureFlagsProvider),
    );

@riverpod
UpdateProfile updateProfile(Ref ref) => UpdateProfile(
      repository: ref.watch(profileRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
      flags: ref.watch(featureFlagsProvider),
    );

@riverpod
ResetPin resetPin(Ref ref) => ResetPin(
      repository: ref.watch(profileRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

@riverpod
DeactivateProfile deactivateProfile(Ref ref) => DeactivateProfile(
      repository: ref.watch(profileRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

/// Every profile of the store, active first (lock screen and the owner's
/// profile list both watch this).
@riverpod
Stream<List<Profile>> allProfiles(Ref ref) =>
    WatchProfiles(ref.watch(profileRepositoryProvider))();
