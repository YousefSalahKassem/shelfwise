import 'dart:ui';

import 'package:shelfwise/core/brand/brand_config.dart';
import 'package:shelfwise/core/brand/tier.dart';
import 'package:shelfwise/core/database/app_database.dart';
import 'package:shelfwise/core/database/schema/tables.dart';
import 'package:shelfwise/core/session/fake_session.dart';

/// Shared test data. IDs match [FakeSession] so sessions and rows line up.
abstract final class Fixtures {
  static final DateTime now = DateTime.utc(2026, 9, 1, 9);
  static int get nowMs => now.millisecondsSinceEpoch;

  static BrandConfig brand({Tier tier = Tier.aisle, String defaultLocale = 'en'}) => BrandConfig(
        id: 'shelfwise',
        appName: 'ShelfWise',
        tier: tier,
        primary: const Color(0xFF0D6A56),
        secondary: const Color(0xFFA86F00),
        logoAsset: 'assets/brands/shelfwise/logo.png',
        logoDarkAsset: 'assets/brands/shelfwise/logo_dark.png',
        iconAsset: 'assets/brands/shelfwise/icon.png',
        defaultLocale: Locale(defaultLocale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        defaultCurrency: 'EGP',
      );

  static const categoryIds = ['cat-dairy', 'cat-cheese', 'cat-drinks'];

  /// Store, branch, owner + staff profiles, 3 categories (Dairy › Cheese, Drinks)
  /// and 20 products with stock (every 5th product is low, product 20 is out).
  static Future<void> seed(AppDatabase db) async {
    final audit = {C.createdAt: nowMs, C.updatedAt: nowMs};
    await db.transaction((txn) async {
      await txn.insert(T.stores, {
        C.id: FakeSession.store.id,
        'name': FakeSession.store.name,
        'currency': 'EGP',
        'locale': 'en',
        ...audit,
      });
      await txn.insert(T.branches, {
        C.id: FakeSession.branch.id,
        C.storeId: FakeSession.store.id,
        'name': 'Main',
        'is_default': 1,
        ...audit,
      });
      for (final p in [FakeSession.owner, FakeSession.staff]) {
        await txn.insert(T.profiles, {
          C.id: p.id,
          C.storeId: FakeSession.store.id,
          'name': p.name,
          'role': p.role.name,
          'pin_hash': 'test-hash',
          'pin_salt': 'test-salt',
          ...audit,
        });
      }
      await txn.insert(T.categories, {C.id: 'cat-dairy', C.storeId: 'store-1', 'name': 'Dairy', 'sort_order': 0, ...audit});
      await txn.insert(T.categories,
          {C.id: 'cat-cheese', C.storeId: 'store-1', 'parent_id': 'cat-dairy', 'name': 'Cheese', 'sort_order': 0, ...audit});
      await txn.insert(T.categories, {C.id: 'cat-drinks', C.storeId: 'store-1', 'name': 'Drinks', 'sort_order': 1, ...audit});
      for (var i = 1; i <= 20; i++) {
        final id = 'prod-$i';
        await txn.insert(T.products, {
          C.id: id,
          C.storeId: 'store-1',
          'category_id': categoryIds[i % 3],
          'name': 'Product $i',
          'sku': 'SKU-$i',
          'barcode': '6220000000${i.toString().padLeft(3, '0')}',
          'unit': 'piece',
          'cost_minor': 1000 + i * 10,
          'price_minor': 1500 + i * 10,
          'reorder_point_milli': 5000,
          ...audit,
        });
        final qty = i == 20 ? 0 : (i % 5 == 0 ? 3 : 20);
        await txn.insert(T.stockLevels, {
          C.productId: id,
          C.branchId: 'branch-1',
          'qty_milli': qty * 1000,
          ...audit,
        });
      }
    });
  }
}
