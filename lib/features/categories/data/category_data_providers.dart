import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/database/db_changes.dart';
import '../../../core/session/session_impl.dart';
import '../../../core/utils/core_providers.dart';
import '../domain/repositories/category_repository.dart';
import 'datasources/category_local_data_source.dart';
import 'repositories/category_repository_impl.dart';

part 'category_data_providers.g.dart';

@Riverpod(keepAlive: true)
CategoryLocalDataSource categoryLocalDataSource(Ref ref) =>
    CategoryLocalDataSource(ref.watch(appDatabaseProvider));

/// The domain interface — never the implementation type.
@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) => CategoryRepositoryImpl(
      database: ref.watch(appDatabaseProvider),
      dataSource: ref.watch(categoryLocalDataSourceProvider),
      changes: ref.watch(dbChangesProvider),
      session: ref.watch(sessionControllerProvider),
      ids: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
    );
