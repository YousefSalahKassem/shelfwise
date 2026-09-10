import 'package:flutter/material.dart';

import '../error/failure.dart';
import '../l10n/failure_messages.dart';
import '../l10n/l10n.dart';
import 'empty_state.dart';

/// Shows a [Failure] (or any error) in the user's language with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = error;
    final message = e is Failure ? failureMessage(l10n, e) : l10n.common_errorGeneric;
    return EmptyState(
      icon: Icons.error_outline,
      title: message,
      action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: Text(l10n.common_retry)),
    );
  }
}
