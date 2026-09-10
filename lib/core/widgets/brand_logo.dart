import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../brand/brand_providers.dart';

/// The brand's logo, switching to the dark variant in dark mode.
class BrandLogo extends ConsumerWidget {
  const BrandLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandConfigProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? brand.logoDarkAsset : brand.logoAsset,
      width: size,
      height: size,
      semanticLabel: brand.appName,
    );
  }
}
