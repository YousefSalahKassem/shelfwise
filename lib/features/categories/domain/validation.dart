import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';

/// Rules for a category name and for the two-level tree.
/// Pure Dart, so the form and the use cases apply exactly the same rules.
abstract final class CategoryValidation {
  static const int maxNameLength = 60;

  /// Max nesting depth (Dairy › Cheese). TECHNICAL_STRUCTURE §6.
  static const int maxDepth = 2;

  /// The trimmed name, or a [ValidationFailure] on `name`.
  static Result<String> name(String raw) {
    final name = raw.trim();
    if (name.isEmpty) {
      return const Err(ValidationFailure(field: 'name', code: 'required'));
    }
    if (name.length > maxNameLength) {
      return const Err(ValidationFailure(field: 'name', code: 'too_long'));
    }
    return Success(name);
  }
}
