import 'package:sqflite_common/sqlite_api.dart';

import 'migration.dart';

/// Schema v1 — TECHNICAL_STRUCTURE §6. Money = INTEGER minor units,
/// quantities = INTEGER thousandths, timestamps = INTEGER UTC epoch ms,
/// ids = TEXT UUID, soft delete via deleted_at.
class M001Initial extends Migration {
  const M001Initial();

  @override
  int get version => 1;

  static const _audit = '''
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER''';

  static const statements = <String>[
    '''
    CREATE TABLE stores (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      currency TEXT NOT NULL,
      locale TEXT NOT NULL,
      $_audit
    )''',
    '''
    CREATE TABLE branches (
      id TEXT PRIMARY KEY,
      store_id TEXT NOT NULL REFERENCES stores(id),
      name TEXT NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0,
      $_audit
    )''',
    '''
    CREATE TABLE profiles (
      id TEXT PRIMARY KEY,
      store_id TEXT NOT NULL REFERENCES stores(id),
      name TEXT NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('owner','staff')),
      pin_hash TEXT NOT NULL,
      pin_salt TEXT NOT NULL,
      locale TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      $_audit
    )''',
    '''
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      store_id TEXT NOT NULL REFERENCES stores(id),
      parent_id TEXT REFERENCES categories(id),
      name TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      $_audit
    )''',
    '''
    CREATE TABLE products (
      id TEXT PRIMARY KEY,
      store_id TEXT NOT NULL REFERENCES stores(id),
      category_id TEXT REFERENCES categories(id),
      name TEXT NOT NULL,
      name_alt TEXT,
      sku TEXT,
      barcode TEXT,
      unit TEXT NOT NULL DEFAULT 'piece'
        CHECK (unit IN ('piece','kg','g','l','ml','box','pack')),
      cost_minor INTEGER NOT NULL DEFAULT 0,
      price_minor INTEGER NOT NULL,
      reorder_point_milli INTEGER NOT NULL DEFAULT 0,
      is_archived INTEGER NOT NULL DEFAULT 0,
      $_audit
    )''',
    '''
    CREATE TABLE product_images (
      product_id TEXT PRIMARY KEY REFERENCES products(id),
      thumb BLOB NOT NULL,
      mime TEXT NOT NULL,
      $_audit
    )''',
    '''
    CREATE TABLE stock_levels (
      product_id TEXT NOT NULL REFERENCES products(id),
      branch_id TEXT NOT NULL REFERENCES branches(id),
      qty_milli INTEGER NOT NULL DEFAULT 0,
      $_audit,
      PRIMARY KEY (product_id, branch_id)
    )''',
    '''
    CREATE TABLE stock_movements (
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL REFERENCES products(id),
      branch_id TEXT NOT NULL REFERENCES branches(id),
      type TEXT NOT NULL CHECK (type IN ('receive','sale','damaged','expired',
        'adjustment','count','transfer_in','transfer_out')),
      qty_delta_milli INTEGER NOT NULL,
      qty_after_milli INTEGER NOT NULL,
      unit_cost_minor INTEGER,
      note TEXT,
      profile_id TEXT NOT NULL REFERENCES profiles(id),
      $_audit
    )''',
    '''
    CREATE TABLE price_changes (
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL REFERENCES products(id),
      old_price_minor INTEGER NOT NULL,
      new_price_minor INTEGER NOT NULL,
      old_cost_minor INTEGER,
      new_cost_minor INTEGER,
      batch_id TEXT,
      profile_id TEXT NOT NULL REFERENCES profiles(id),
      $_audit
    )''',
    '''
    CREATE TABLE stock_alerts (
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL REFERENCES products(id),
      branch_id TEXT NOT NULL REFERENCES branches(id),
      level TEXT NOT NULL CHECK (level IN ('low','out')),
      triggered_at INTEGER NOT NULL,
      resolved_at INTEGER,
      acknowledged_at INTEGER,
      $_audit
    )''',
    '''
    CREATE TABLE app_events (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      props TEXT,
      profile_id TEXT,
      $_audit
    )''',
    '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      $_audit
    )''',
    // Indexes
    'CREATE UNIQUE INDEX ux_products_store_barcode ON products(store_id, barcode) '
        'WHERE barcode IS NOT NULL AND deleted_at IS NULL',
    'CREATE INDEX ix_products_store_sku ON products(store_id, sku)',
    'CREATE INDEX ix_products_store_category ON products(store_id, category_id)',
    'CREATE INDEX ix_products_store_name ON products(store_id, name COLLATE NOCASE)',
    'CREATE INDEX ix_categories_store_parent ON categories(store_id, parent_id)',
    'CREATE INDEX ix_movements_product_created ON stock_movements(product_id, created_at)',
    'CREATE INDEX ix_movements_created ON stock_movements(created_at)',
    'CREATE INDEX ix_price_changes_product ON price_changes(product_id, created_at)',
    'CREATE INDEX ix_price_changes_batch ON price_changes(batch_id)',
    'CREATE INDEX ix_alerts_open ON stock_alerts(resolved_at, level)',
    'CREATE INDEX ix_events_name_created ON app_events(name, created_at)',
  ];

  @override
  Future<void> up(DatabaseExecutor db) async {
    for (final sql in statements) {
      await db.execute(sql);
    }
  }
}
