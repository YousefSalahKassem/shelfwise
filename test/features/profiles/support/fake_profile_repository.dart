import 'dart:async';

import 'package:shelfwise/core/auth/permission.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/error/result.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/features/profiles/domain/repositories/profile_repository.dart';
import 'package:shelfwise/features/profiles/domain/value_objects/pin.dart';

/// In-memory [ProfileRepository]. Widget tests use it because sqflite futures
/// never complete inside a widget test's fake-async zone.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({List<Profile>? profiles, Map<String, String>? pins})
      : profiles = profiles ?? [FakeSession.owner, FakeSession.staff],
        pins = pins ?? {FakeSession.owner.id: '1234', FakeSession.staff.id: '5678'};

  final List<Profile> profiles;
  final Map<String, String> pins;
  final _controller = StreamController<List<Profile>>.broadcast();

  var nextId = 1;
  Failure? failWith;

  void dispose() => _controller.close();

  void _emit() => _controller.add(List.unmodifiable(profiles));

  @override
  Stream<List<Profile>> watchAll() async* {
    yield List.unmodifiable(profiles);
    yield* _controller.stream;
  }

  @override
  Future<Result<Profile>> create({
    required String name,
    required Role role,
    required String pin,
    String? locale,
  }) async {
    if (failWith case final failure?) return Err(failure);
    final profile = Profile(
      id: 'profile-${nextId++}',
      storeId: FakeSession.store.id,
      name: name,
      role: role,
      locale: locale,
    );
    profiles.add(profile);
    pins[profile.id] = pin;
    _emit();
    return Success(profile);
  }

  @override
  Future<Result<Profile>> update(Profile profile) async {
    if (failWith case final failure?) return Err(failure);
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index < 0) return const Err(NotFoundFailure('profile'));
    profiles[index] = profile;
    _emit();
    return Success(profile);
  }

  @override
  Future<Result<void>> resetPin(String profileId, String newPin) async {
    if (failWith case final failure?) return Err(failure);
    pins[profileId] = newPin;
    return ok;
  }

  @override
  Future<Result<void>> deactivate(String profileId) async {
    if (failWith case final failure?) return Err(failure);
    final index = profiles.indexWhere((p) => p.id == profileId);
    if (index < 0) return const Err(NotFoundFailure('profile'));
    profiles[index] = profiles[index].copyWith(isActive: false);
    _emit();
    return ok;
  }

  @override
  Future<Result<Profile>> verifyPin(String profileId, String pin) async {
    final profile = profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null || !profile.isActive || pins[profileId] != pin) {
      return const Err(ValidationFailure(field: 'pin', code: PinFailureCodes.wrongPin));
    }
    return Success(profile);
  }
}
