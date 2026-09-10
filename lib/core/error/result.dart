import 'failure.dart';

/// Outcome of a use case or repository call. Never throw across layers.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Err<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        Err<T>(:final failure) => failure,
      };

  R fold<R>(R Function(T value) onSuccess, R Function(Failure failure) onError) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        Err<T>(:final failure) => onError(failure),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Success<R>(transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
  @override
  String toString() => 'Success($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
  @override
  String toString() => 'Err($failure)';
}

/// Convenience for `Result<void>` successes.
const Result<void> ok = Success<void>(null);
