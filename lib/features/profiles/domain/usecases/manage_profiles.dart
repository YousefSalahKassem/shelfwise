import '../../../../core/auth/permission.dart';
import '../../../../core/brand/feature_flags.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../repositories/profile_repository.dart';
import '../value_objects/pin.dart';

/// Name used in [FeatureLockedFailure] when the staff limit is reached.
const staffLimitFeature = 'maxStaffProfiles';

/// Every profile of the store, active first. No permission check: the lock
/// screen must list profiles while the app is locked.
class WatchProfiles {
  const WatchProfiles(this.repository);
  final ProfileRepository repository;

  Stream<List<Profile>> call() => repository.watchAll();
}

/// Owner-only. Enforces `FeatureFlags.maxStaffProfiles` (Shelf = 3).
class CreateStaffProfile {
  const CreateStaffProfile({
    required this.repository,
    required this.session,
    required this.flags,
  });

  final ProfileRepository repository;
  final SessionReader session;
  final FeatureFlags flags;

  Future<Result<Profile>> call({
    required String name,
    required String pin,
    String? locale,
  }) async {
    if (!session.can(Permission.manageProfiles)) {
      return const Err(PermissionFailure('manageProfiles'));
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(ValidationFailure(field: 'name', code: 'required'));
    }
    if (!Pin.isValid(pin)) {
      return const Err(ValidationFailure(field: 'pin', code: PinFailureCodes.length));
    }
    if (await _staffLimitReached(repository, flags)) {
      return const Err(FeatureLockedFailure(staffLimitFeature));
    }
    return repository.create(name: trimmed, role: Role.staff, pin: pin, locale: locale);
  }
}

/// Owner-only rename / language change / reactivation.
class UpdateProfile {
  const UpdateProfile({
    required this.repository,
    required this.session,
    required this.flags,
  });

  final ProfileRepository repository;
  final SessionReader session;
  final FeatureFlags flags;

  Future<Result<Profile>> call(Profile profile) async {
    if (!session.can(Permission.manageProfiles)) {
      return const Err(PermissionFailure('manageProfiles'));
    }
    if (profile.name.trim().isEmpty) {
      return const Err(ValidationFailure(field: 'name', code: 'required'));
    }
    final wasActive = await _isActive(repository, profile.id);
    if (profile.isActive && !wasActive && profile.role == Role.staff) {
      if (await _staffLimitReached(repository, flags)) {
        return const Err(FeatureLockedFailure(staffLimitFeature));
      }
    }
    return repository.update(profile.copyWith(name: profile.name.trim()));
  }
}

/// Owner-only. Changing a PIN never reveals the old one.
class ResetPin {
  const ResetPin({required this.repository, required this.session});

  final ProfileRepository repository;
  final SessionReader session;

  Future<Result<void>> call(String profileId, String newPin) async {
    if (!session.can(Permission.manageProfiles)) {
      return const Err(PermissionFailure('manageProfiles'));
    }
    if (!Pin.isValid(newPin)) {
      return const Err(ValidationFailure(field: 'pin', code: PinFailureCodes.length));
    }
    return repository.resetPin(profileId, newPin);
  }
}

/// Owner-only. Profiles are never deleted — stock movements reference them.
class DeactivateProfile {
  const DeactivateProfile({required this.repository, required this.session});

  final ProfileRepository repository;
  final SessionReader session;

  Future<Result<void>> call(String profileId) async {
    if (!session.can(Permission.manageProfiles)) {
      return const Err(PermissionFailure('manageProfiles'));
    }
    final profiles = await repository.watchAll().first;
    final profile = profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) return const Err(NotFoundFailure('profile'));
    if (profile.role == Role.owner) {
      return const Err(ValidationFailure(field: 'role', code: 'owner_protected'));
    }
    return repository.deactivate(profileId);
  }
}

Future<bool> _staffLimitReached(ProfileRepository repository, FeatureFlags flags) async {
  final max = flags.maxStaffProfiles;
  if (max == null) return false;
  final profiles = await repository.watchAll().first;
  final active = profiles.where((p) => p.role == Role.staff && p.isActive).length;
  return active >= max;
}

Future<bool> _isActive(ProfileRepository repository, String profileId) async {
  final profiles = await repository.watchAll().first;
  return profiles.where((p) => p.id == profileId).firstOrNull?.isActive ?? false;
}
