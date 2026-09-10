/// Spacing scale (dp). Use these instead of magic numbers.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Minimum touch target.
  static const double minTarget = 48;
}

abstract final class AppRadii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
}

/// Layout breakpoints (TECHNICAL_STRUCTURE §10).
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
}
