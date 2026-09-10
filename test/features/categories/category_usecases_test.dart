import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/error/result.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/features/categories/domain/entities/category.dart';
import 'package:shelfwise/features/categories/domain/repositories/category_repository.dart';
import 'package:shelfwise/features/categories/domain/usecases/create_category.dart';
import 'package:shelfwise/features/categories/domain/usecases/delete_category.dart';
import 'package:shelfwise/features/categories/domain/usecases/move_category.dart';
import 'package:shelfwise/features/categories/domain/usecases/rename_category.dart';
import 'package:shelfwise/features/categories/domain/validation.dart';

/// Records what reached the repository so the use-case rules can be tested
/// without a database.
class _SpyCategoryRepository implements CategoryRepository {
  final calls = <String>[];
  Result<Category> next = const Success(Category(id: 'c1', name: 'Dairy'));

  @override
  Future<Result<Category>> create(String name, {String? parentId}) async {
    calls.add('create:$name:$parentId');
    return next;
  }

  @override
  Future<Result<Category>> rename(String id, String name) async {
    calls.add('rename:$id:$name');
    return next;
  }

  @override
  Future<Result<void>> move(String id, {String? parentId, required int sortOrder}) async {
    calls.add('move:$id:$parentId:$sortOrder');
    return ok;
  }

  @override
  Future<Result<void>> delete(String id, {String? moveProductsTo}) async {
    calls.add('delete:$id:$moveProductsTo');
    return ok;
  }

  @override
  Stream<List<CategoryNode>> watchTree() => const Stream.empty();
}

void main() {
  late _SpyCategoryRepository repository;

  setUp(() => repository = _SpyCategoryRepository());

  group('name validation', () {
    test('rejects a blank name', () {
      final result = CategoryValidation.name('   ');
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect((result.failureOrNull! as ValidationFailure).code, 'required');
    });

    test('rejects a name over 60 characters', () {
      final result = CategoryValidation.name('x' * 61);
      expect((result.failureOrNull! as ValidationFailure).code, 'too_long');
    });

    test('trims the name it accepts', () {
      expect(CategoryValidation.name('  Dairy  ').valueOrNull, 'Dairy');
    });
  });

  group('permissions', () {
    test('staff cannot create a category', () async {
      final useCase = CreateCategory(
        repository: repository,
        session: FakeSession.staffSession,
      );
      final result = await useCase('Dairy');
      expect(result.failureOrNull, isA<PermissionFailure>());
      expect(repository.calls, isEmpty);
    });

    test('staff cannot rename, move or delete', () async {
      const session = FakeSession.staffSession;
      expect(
        (await RenameCategory(repository: repository, session: session)('c1', 'x'))
            .failureOrNull,
        isA<PermissionFailure>(),
      );
      expect(
        (await MoveCategory(repository: repository, session: session)('c1', sortOrder: 0))
            .failureOrNull,
        isA<PermissionFailure>(),
      );
      expect(
        (await DeleteCategory(repository: repository, session: session)('c1')).failureOrNull,
        isA<PermissionFailure>(),
      );
      expect(repository.calls, isEmpty);
    });

    test('the owner may create, and the name is trimmed first', () async {
      final useCase = CreateCategory(
        repository: repository,
        session: FakeSession.ownerSession,
      );
      final result = await useCase('  Dairy  ', parentId: null);
      expect(result.isSuccess, isTrue);
      expect(repository.calls, ['create:Dairy:null']);
    });
  });

  test('a negative sort order is rejected before reaching the repository', () async {
    final useCase = MoveCategory(
      repository: repository,
      session: FakeSession.ownerSession,
    );
    final result = await useCase('c1', sortOrder: -1);
    expect((result.failureOrNull! as ValidationFailure).field, 'sortOrder');
    expect(repository.calls, isEmpty);
  });

  test('delete forwards the category products should move to', () async {
    final useCase = DeleteCategory(
      repository: repository,
      session: FakeSession.ownerSession,
    );
    await useCase('c1', moveProductsTo: 'c2');
    expect(repository.calls, ['delete:c1:c2']);
  });
}
