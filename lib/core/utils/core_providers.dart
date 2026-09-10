import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'clock.dart';
import 'ids.dart';

part 'core_providers.g.dart';

/// Override in tests with [FixedClock].
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

/// Override in tests with [SequentialIdGenerator].
@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => const UuidIdGenerator();
