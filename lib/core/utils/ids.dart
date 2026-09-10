import 'package:uuid/uuid.dart';

/// Generates primary keys (UUID v4 strings). Overridable in tests.
abstract interface class IdGenerator {
  String newId();
}

class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator();
  static const _uuid = Uuid();
  @override
  String newId() => _uuid.v4();
}

/// Deterministic ids for tests: `id-1`, `id-2`, …
class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator([this.prefix = 'id']);
  final String prefix;
  int _n = 0;
  @override
  String newId() => '$prefix-${++_n}';
}
