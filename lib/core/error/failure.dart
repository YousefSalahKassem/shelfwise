/// Errors that cross layer boundaries. Carry l10n keys, never user-facing text.
///
/// Presentation turns a [Failure] into a message with `failureMessage()`
/// (lib/core/l10n/failure_messages.dart).
sealed class Failure {
  const Failure();

  /// Key in the common ARB file used to describe this failure.
  String get l10nKey;
}

/// Input did not pass validation. [field] names the input, [code] the rule.
final class ValidationFailure extends Failure {
  const ValidationFailure({required this.field, required this.code});
  final String field;
  final String code;
  @override
  String get l10nKey => 'common_errorValidation';
  @override
  String toString() => 'ValidationFailure($field: $code)';
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(this.entity, [this.id]);
  final String entity;
  final String? id;
  @override
  String get l10nKey => 'common_errorNotFound';
  @override
  String toString() => 'NotFoundFailure($entity ${id ?? ''})';
}

/// A unique value already exists (e.g. duplicate barcode).
final class ConflictFailure extends Failure {
  const ConflictFailure(this.field);
  final String field;
  @override
  String get l10nKey => 'common_errorConflict';
  @override
  String toString() => 'ConflictFailure($field)';
}

/// The current profile's role doesn't allow this action.
final class PermissionFailure extends Failure {
  const PermissionFailure(this.permission);
  final String permission;
  @override
  String get l10nKey => 'common_errorPermission';
  @override
  String toString() => 'PermissionFailure($permission)';
}

/// The brand's tier doesn't include this feature.
final class FeatureLockedFailure extends Failure {
  const FeatureLockedFailure(this.feature);
  final String feature;
  @override
  String get l10nKey => 'common_errorFeatureLocked';
  @override
  String toString() => 'FeatureLockedFailure($feature)';
}

/// Database, file or platform error.
final class StorageFailure extends Failure {
  const StorageFailure(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String get l10nKey => 'common_errorStorage';
  @override
  String toString() => 'StorageFailure($message)';
}
