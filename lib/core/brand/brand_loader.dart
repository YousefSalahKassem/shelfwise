import 'dart:convert';

import 'package:flutter/services.dart';

import 'brand_config.dart';

/// Loads `assets/brands/<brandId>/brand.json` from the bundle.
class BrandLoader {
  const BrandLoader(this.bundle);
  final AssetBundle bundle;

  static String pathFor(String brandId) => 'assets/brands/$brandId/brand.json';

  Future<BrandConfig> load(String brandId) async {
    final raw = await bundle.loadString(pathFor(brandId));
    final json = jsonDecode(raw);
    if (json is! Map) throw BrandConfigException(['brand.json must be a JSON object']);
    final config = BrandConfig.fromJson(json.cast<String, Object?>());
    if (config.id != brandId) {
      throw BrandConfigException(['"id" (${config.id}) must match folder name ($brandId)']);
    }
    return config;
  }
}
