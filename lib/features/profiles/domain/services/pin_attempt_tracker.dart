/// Brute-force guard for the lock screen: after [maxAttempts] wrong PINs a
/// profile is frozen for [cooldown]. Pure Dart and clock-driven so it can be
/// unit-tested; state is per-process (a restart clears it, which is fine — the
/// database never leaves the device).
class PinAttemptTracker {
  PinAttemptTracker({this.maxAttempts = 5, this.cooldown = const Duration(seconds: 30)});

  final int maxAttempts;
  final Duration cooldown;

  final _failures = <String, int>{};
  final _frozenUntil = <String, DateTime>{};

  /// Seconds left before [profileId] may try again, or null if it may try now.
  int? cooldownSeconds(String profileId, DateTime now) {
    final until = _frozenUntil[profileId];
    if (until == null) return null;
    if (!until.isAfter(now)) {
      _frozenUntil.remove(profileId);
      _failures.remove(profileId);
      return null;
    }
    return (until.difference(now).inMilliseconds / 1000).ceil();
  }

  bool isLockedOut(String profileId, DateTime now) => cooldownSeconds(profileId, now) != null;

  /// Records a wrong PIN; starts the cooldown once [maxAttempts] is reached.
  void recordFailure(String profileId, DateTime now) {
    final count = (_failures[profileId] ?? 0) + 1;
    _failures[profileId] = count;
    if (count >= maxAttempts) _frozenUntil[profileId] = now.add(cooldown);
  }

  void recordSuccess(String profileId) {
    _failures.remove(profileId);
    _frozenUntil.remove(profileId);
  }
}
