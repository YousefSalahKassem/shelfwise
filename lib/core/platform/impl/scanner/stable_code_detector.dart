// OWNER: A5. Pure Dart — no Flutter, so it can be unit-tested on its own.

/// Turns a stream of noisy camera detections into one *stable* code.
///
/// Cameras happily report a misread digit once; asking for the same value
/// [confirmations] times in a row costs a few hundred milliseconds and removes
/// nearly all of those. A different value restarts the count.
class StableCodeDetector {
  StableCodeDetector({this.confirmations = 2})
      : assert(confirmations >= 1, 'At least one detection is needed.');

  /// How often the same value must be seen before it is accepted.
  final int confirmations;

  String? _candidate;
  int _seen = 0;

  /// Feeds one detection. Returns the code once it is stable, otherwise null.
  String? offer(String? code) {
    final value = code?.trim();
    if (value == null || value.isEmpty) return null;
    if (value == _candidate) {
      _seen++;
    } else {
      _candidate = value;
      _seen = 1;
    }
    return _seen >= confirmations ? value : null;
  }

  void reset() {
    _candidate = null;
    _seen = 0;
  }
}
