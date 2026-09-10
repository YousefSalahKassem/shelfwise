import '../../../../core/auth/permission.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';

abstract interface class ProfileRepository {
  /// Active and inactive profiles of the current store.
  Stream<List<Profile>> watchAll();

  Future<Result<Profile>> create({
    required String name,
    required Role role,
    required String pin,
    String? locale,
  });

  Future<Result<Profile>> update(Profile profile);

  Future<Result<void>> resetPin(String profileId, String newPin);

  /// Profiles are never deleted (movements reference them).
  Future<Result<void>> deactivate(String profileId);

  /// Returns the profile when [pin] is correct, else a [ValidationFailure]
  /// with code `wrong_pin` or `locked_out`.
  Future<Result<Profile>> verifyPin(String profileId, String pin);
}
