/// Compile-time configuration passed with `--dart-define`.
///
/// ```bash
/// flutter run --dart-define=BRAND_ID=demo-green --dart-define=ENV=dev
/// ```
abstract final class Env {
  /// Folder name under `assets/brands/`.
  static const String brandId =
      String.fromEnvironment('BRAND_ID', defaultValue: 'shelfwise');

  /// `dev` or `prod`.
  static const String environment =
      String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isProd => environment == 'prod';
}
