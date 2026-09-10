import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';

/// Shows a translated message when a category action failed; silent on success.
void showCategoryResult(BuildContext context, Result<Object?> result) {
  if (result case Err(:final failure)) {
    showCategoryMessage(context, categoryFailureMessage(context, failure));
  }
}

/// Field-level failures get a specific sentence; anything else falls back to
/// the shared failure text.
String categoryFailureMessage(BuildContext context, Failure failure) {
  final l10n = context.l10n;
  return switch (failure) {
    ConflictFailure(field: 'name') => l10n.catalogue_categoryNameTaken,
    ValidationFailure(code: 'max_depth') => l10n.catalogue_categoryMaxDepth,
    ValidationFailure(code: 'not_empty') => l10n.catalogue_categoryHasProducts,
    ValidationFailure(field: 'name', code: 'required') => l10n.catalogue_categoryNameRequired,
    ValidationFailure(field: 'name', code: 'too_long') => l10n.catalogue_categoryNameTooLong,
    _ => failureMessage(l10n, failure),
  };
}

void showCategoryMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}
