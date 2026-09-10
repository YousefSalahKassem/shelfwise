import 'package:flutter/widgets.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/quantity.dart';

/// Translated name of a [ProductUnit].
String unitLabel(BuildContext context, ProductUnit unit) {
  final l10n = context.l10n;
  return switch (unit) {
    ProductUnit.piece => l10n.catalogue_unitPiece,
    ProductUnit.kg => l10n.catalogue_unitKg,
    ProductUnit.g => l10n.catalogue_unitG,
    ProductUnit.l => l10n.catalogue_unitL,
    ProductUnit.ml => l10n.catalogue_unitMl,
    ProductUnit.box => l10n.catalogue_unitBox,
    ProductUnit.pack => l10n.catalogue_unitPack,
  };
}
