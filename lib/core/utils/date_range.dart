import 'package:meta/meta.dart';

/// Inclusive start, exclusive end. Pure Dart (domain-safe) alternative to
/// Flutter's DateTimeRange.
@immutable
class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
}
