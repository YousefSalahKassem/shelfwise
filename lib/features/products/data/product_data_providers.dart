import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/database/db_changes.dart';
import '../../../core/session/session_impl.dart';
import '../../../core/utils/core_providers.dart';
import '../domain/repositories/product_detail_repository.dart';
import '../domain/repositories/product_repository.dart';
import 'datasources/product_local_data_source.dart';
import 'repositories/product_repository_impl.dart';

part 'product_data_providers.g.dart';

@Riverpod(keepAlive: true)
ProductLocalDataSource productLocalDataSource(Ref ref) =>
    ProductLocalDataSource(ref.watch(appDatabaseProvider));

/// One implementation object behind two domain interfaces.
@Riverpod(keepAlive: true)
ProductRepositoryImpl _productRepositoryImpl(Ref ref) => ProductRepositoryImpl(
      database: ref.watch(appDatabaseProvider),
      dataSource: ref.watch(productLocalDataSourceProvider),
      changes: ref.watch(dbChangesProvider),
      session: ref.watch(sessionControllerProvider),
      ids: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
    );

/// The domain interface — never the implementation type.
@Riverpod(keepAlive: true)
ProductRepository productRepository(Ref ref) => ref.watch(_productRepositoryImplProvider);

@Riverpod(keepAlive: true)
ProductDetailRepository productDetailRepository(Ref ref) =>
    ref.watch(_productRepositoryImplProvider);
