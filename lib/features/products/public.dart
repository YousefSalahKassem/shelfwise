// OWNER: A2. Public surface of the products feature — the only thing other
// features may import besides `domain/`.
import 'package:flutter/material.dart';

import 'domain/entities/product.dart';
import 'presentation/widgets/product_picker_sheet.dart';

export 'domain/entities/product.dart';
export 'presentation/widgets/product_tile.dart' show ProductThumbnail, ProductTile;

/// Search-or-scan product chooser used by stock, pricing and the dashboard.
/// Returns the chosen product, or null when the sheet is dismissed.
Future<Product?> showProductPicker(BuildContext context) => showProductPickerSheet(context);
