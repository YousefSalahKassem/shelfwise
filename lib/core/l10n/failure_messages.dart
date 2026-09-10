import '../error/failure.dart';
import 'gen/app_localizations.dart';

/// User-facing text for a [Failure].
String failureMessage(AppLocalizations l10n, Failure failure) => switch (failure) {
      ValidationFailure() => l10n.common_errorValidation,
      NotFoundFailure() => l10n.common_errorNotFound,
      ConflictFailure() => l10n.common_errorConflict,
      PermissionFailure() => l10n.common_errorPermission,
      FeatureLockedFailure() => l10n.common_errorFeatureLocked,
      StorageFailure() => l10n.common_errorStorage,
    };
