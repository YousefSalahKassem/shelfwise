import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/product.dart';

/// Field rules for a [ProductDraft]. Pure Dart, so the form, the use cases and
/// (later) CSV import all reject exactly the same input.
///
/// Uniqueness of barcode and SKU needs the database and is checked by the
/// repository, which returns a [ConflictFailure].
abstract final class ProductValidation {
  static const int maxNameLength = 120;
  static const int maxCodeLength = 40;

  /// The draft with text fields trimmed and blanks turned into null, or the
  /// first [ValidationFailure].
  static Result<ProductDraft> normalize(ProductDraft draft) {
    final name = draft.name.trim();
    if (name.isEmpty) {
      return const Err(ValidationFailure(field: 'name', code: 'required'));
    }
    if (name.length > maxNameLength) {
      return const Err(ValidationFailure(field: 'name', code: 'too_long'));
    }

    final nameAlt = _blankToNull(draft.nameAlt);
    if (nameAlt != null && nameAlt.length > maxNameLength) {
      return const Err(ValidationFailure(field: 'nameAlt', code: 'too_long'));
    }

    final sku = _blankToNull(draft.sku);
    if (sku != null && sku.length > maxCodeLength) {
      return const Err(ValidationFailure(field: 'sku', code: 'too_long'));
    }

    final barcode = _blankToNull(draft.barcode);
    if (barcode != null && barcode.length > maxCodeLength) {
      return const Err(ValidationFailure(field: 'barcode', code: 'too_long'));
    }

    if (draft.price.isNegative) {
      return const Err(ValidationFailure(field: 'price', code: 'negative'));
    }
    if (draft.cost.isNegative) {
      return const Err(ValidationFailure(field: 'cost', code: 'negative'));
    }
    if (draft.price.currency != draft.cost.currency) {
      return const Err(ValidationFailure(field: 'price', code: 'currency_mismatch'));
    }

    return Success(
      draft.copyWith(name: name, nameAlt: nameAlt, sku: sku, barcode: barcode),
    );
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
