import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'empty_state.dart';

/// Stub screen used by W0 for every route; feature agents replace them.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String Function(AppLocalizations l10n) title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(title(l10n))),
      body: EmptyState(
        icon: Icons.construction_outlined,
        title: l10n.common_comingSoonTitle,
        message: l10n.common_placeholderBody,
      ),
    );
  }
}
