import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/db_changes.dart';
import '../../../core/session/session_impl.dart';
import '../../../core/utils/core_providers.dart';
import '../../profiles/domain/services/pin_hasher.dart';
import '../domain/repositories/store_repository.dart';
import '../domain/usecases/create_store.dart';
import '../domain/usecases/update_store.dart';
import 'datasources/store_local_data_source.dart';
import 'repositories/store_repository_impl.dart';

part 'store_providers.g.dart';

/// Work factor for PIN hashing. Onboarding and profiles must agree, so both
/// use the default [PinHasher] configuration.
const pinHasher = PinHasher();

@Riverpod(keepAlive: true)
StoreLocalDataSource storeLocalDataSource(Ref ref) => StoreLocalDataSource(
      db: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
      ids: ref.watch(idGeneratorProvider),
      hasher: pinHasher,
    );

@Riverpod(keepAlive: true)
StoreRepository storeRepository(Ref ref) => StoreRepositoryImpl(
      local: ref.watch(storeLocalDataSourceProvider),
      changes: ref.watch(dbChangesProvider),
    );

@riverpod
CreateStore createStore(Ref ref) => CreateStore(
  repository: ref.watch(storeRepositoryProvider),
  analytics: ref.watch(analyticsServiceProvider),
);

@riverpod
UpdateStore updateStore(Ref ref) => UpdateStore(
  repository: ref.watch(storeRepositoryProvider),
  session: ref.watch(sessionControllerProvider),
);
