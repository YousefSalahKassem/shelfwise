/// A PIN as the user typed it. Pure Dart — no hashing here, that is
/// [PinHasher]'s job (TECHNICAL_STRUCTURE §15).
extension type const Pin._(String value) {
  static const minLength = 4;
  static const maxLength = 6;

  /// Null when [input] is not [minLength]–[maxLength] digits.
  static Pin? tryParse(String input) {
    if (input.length < minLength || input.length > maxLength) return null;
    for (final c in input.codeUnits) {
      if (c < 0x30 || c > 0x39) return null;
    }
    return Pin._(input);
  }

  static bool isValid(String input) => tryParse(input) != null;

  String get digits => value;
}

/// `ValidationFailure.code` values the lock screen understands
/// (see `ProfileRepository.verifyPin`).
abstract final class PinFailureCodes {
  static const wrongPin = 'wrong_pin';
  static const lockedOut = 'locked_out';
  static const length = 'pin_length';
}
