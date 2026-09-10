import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/clock.dart';
import '../repositories/profile_repository.dart';
import '../services/pin_attempt_tracker.dart';
import '../value_objects/pin.dart';

/// Verifies a PIN on the lock screen and guards against brute force.
///
/// The cooldown lives here rather than in the repository so the screen can show
/// how many seconds are left ([cooldownSeconds]); the repository only ever
/// answers "right PIN" or "wrong PIN".
class UnlockProfile {
  UnlockProfile({
    required this.repository,
    required this.analytics,
    required this.clock,
    PinAttemptTracker? attempts,
  }) : attempts = attempts ?? PinAttemptTracker();

  final ProfileRepository repository;
  final AnalyticsService analytics;
  final Clock clock;
  final PinAttemptTracker attempts;

  /// Seconds left before [profileId] may try again, or null when it may now.
  int? cooldownSeconds(String profileId) => attempts.cooldownSeconds(profileId, clock.now());

  /// [switching] is true when another profile was already signed in during this
  /// run of the app — that is a `profile_switched`, not a `session_started`.
  Future<Result<Profile>> call(
    String profileId,
    String pin, {
    required bool switching,
  }) async {
    final now = clock.now();
    final cooldown = attempts.cooldownSeconds(profileId, now);
    if (cooldown != null) {
      return const Err(ValidationFailure(field: 'pin', code: PinFailureCodes.lockedOut));
    }
    if (!Pin.isValid(pin)) {
      attempts.recordFailure(profileId, now);
      return const Err(ValidationFailure(field: 'pin', code: PinFailureCodes.wrongPin));
    }

    final result = await repository.verifyPin(profileId, pin);
    switch (result) {
      case Success(:final value):
        attempts.recordSuccess(profileId);
        await analytics.log(
          switching ? AppEvent.profileSwitched : AppEvent.sessionStarted,
          {'role': value.role.name},
        );
      case Err():
        attempts.recordFailure(profileId, now);
    }
    return result;
  }
}
