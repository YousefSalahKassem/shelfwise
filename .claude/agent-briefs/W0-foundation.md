# W0 — Foundation & contracts (lead agent, serial)

| | |
|---|---|
| **Wave** | 0 — must finish and pass gate G0 before any other agent starts |
| **Depends on** | Nothing |
| **Owns** | Everything listed for "W0 / lead" in AGENT_PHASES §5.1, plus stub files for every feature (replaced later by their owners) |
| **Read first** | TECHNICAL_STRUCTURE §1–§10, §13; PLAN §5 P0–P1 |
| **Business-plan features** | Brand setup (runtime), multi-tenant isolation, AR/EN infrastructure, multi-theme |

## Goal

Create a running, empty, white-label app **plus every shared contract**, so seven agents can build features in parallel without editing the same files.

## Tasks

### 1. Project & tooling
- [ ] `flutter create --platforms=android,ios,web,windows,macos --org <org> shelfwise`
- [ ] Add **all** MVP dependencies now (agents may not touch `pubspec.yaml`): `flutter_riverpod`, `riverpod_annotation`, `go_router`, `freezed_annotation`, `json_annotation`, `sqflite`, `sqflite_common_ffi`, `sqflite_common_ffi_web`, `path`, `path_provider`, `intl`, `flutter_localizations`, `flutter_local_notifications`, `mobile_scanner`, `file_picker`, `csv`, `share_plus`, `crypto`, `uuid`, `image` (thumbnail compression); dev: `build_runner`, `riverpod_generator`, `riverpod_lint`, `freezed`, `json_serializable`, `mocktail`, `flutter_lints`, `integration_test`
- [ ] `analysis_options.yaml`, `build.yaml`, `l10n.yaml`, `.gitignore` (generated `*.g.dart`, `*.freezed.dart`, merged ARBs)
- [ ] `dart run sqflite_common_ffi_web:setup`; commit `web/sqlite3.wasm`, `web/sqflite_sw.js`
- [ ] `tools/scripts/merge_arb.dart`: merges `lib/core/l10n/common_{en,ar}.arb` + every `lib/features/*/l10n/*_{en,ar}.arb` + `lib/core/**/impl/l10n/*_{en,ar}.arb` into `lib/core/l10n/arb/app_{en,ar}.arb`; fails on duplicate keys, missing ar/en pair, or wrong prefix

### 2. Core runtime
- [ ] `main.dart` / `bootstrap.dart` / `app.dart` per TECHNICAL_STRUCTURE §4, §7, §8
- [ ] `core/database`: `db_factory` (io/web/stub), `AppDatabase` (open, `PRAGMA foreign_keys=ON`, migration runner), `m001_initial` with the **complete v1 schema + indexes** (TECHNICAL_STRUCTURE §6), `schema/` constants per table, `db_changes.dart` (`enum DbTable`, `dbChangesProvider`, `notify(Set<DbTable>)`)
- [ ] `core/utils`: `Money` (minor units, currency, add/sub/percent, rounding steps 0.05/0.25/0.50/1.00), `Quantity` (thousandths, unit), `IdGenerator` (UUID v4), `Clock` — all with unit tests
- [ ] `core/error`: `Result`, `Success`, `Err`, `Failure` hierarchy with l10n keys
- [ ] `core/brand`: `BrandConfig` (+ JSON validation), `BrandLoader`, `enum Tier {shelf, aisle, chain}`, `enum FeatureFlag {...}` covering **every** gated feature in AGENT_PHASES §4, `FeatureFlags` matrix per TECHNICAL_STRUCTURE §7, `featureFlagsProvider`
- [ ] `core/theme`: `buildTheme(brand, brightness)`, `StockColors`, `AppSpacing`, `AppRadii`, `AppTypography.forLocale`; bundle fonts (Arabic + Latin)
- [ ] `core/l10n`: `common_en.arb` / `common_ar.arb` (OK, Cancel, Save, errors for each `Failure`, empty states)
- [ ] `core/widgets`: `AppScaffold` (bottom nav < 600 dp, NavigationRail ≥ 600), `MoneyText`, `QuantityText`, `StockBadge`, `EmptyState`, `ErrorView`, `ConfirmDialog`, `PinPad`
- [ ] Sample brands `assets/brands/shelfwise/` and `assets/brands/demo-green/`

### 3. Frozen contracts (write interfaces + fakes, not implementations)
- [ ] `core/auth/permission.dart`
  ```dart
  enum Role { owner, staff }
  enum Permission { viewCatalogue, editCatalogue, editPrices, recordStock, adjustStock,
                    setReorderPoints, manageProfiles, manageSettings, importExport, backupRestore }
  const Map<Role, Set<Permission>> defaultRolePermissions = {...}; // TECHNICAL_STRUCTURE §10
  ```
- [ ] `core/session/session_reader.dart`
  ```dart
  abstract interface class SessionReader {
    Store? get currentStore; Branch? get currentBranch; Profile? get currentProfile;
    bool can(Permission p);
  }
  // sessionReaderProvider — W0 provides FakeSession (owner, default store/branch)
  ```
- [ ] `core/analytics/app_event.dart` — `enum AppEvent` with every pilot event (TECHNICAL_STRUCTURE §11) and `AnalyticsService.log(AppEvent, [Map<String,Object?> props])`; no-op impl
- [ ] `core/platform/`: `ScannerService { Future<String?> scan(BuildContext); bool get hasCamera; }`, `NotificationService { Future<bool> requestPermission(); Future<void> showLowStock(LowStockNotice n); }`, `FileService { Future<PickedFile?> pick({List<String> ext}); Future<void> save(String name, Uint8List bytes, String mime); }` + fakes
- [ ] `core/router/route_paths.dart` — every MVP path constant; `feature_routes.dart` imports `features/<f>/presentation/routes.dart` for: onboarding, profiles, settings, categories, products, pricing, stock, alerts, dashboard, import_export, backup; router guards (onboarding, lock, permission, flag)
- [ ] **Domain contracts** — for each feature: `@freezed` entities + `abstract interface class …Repository`. Minimum set:

  | Feature | Entities | Repository methods (all return `Result`/`Stream`) |
  |---|---|---|
  | onboarding/profiles | `Store`, `Branch`, `Profile` | `StoreRepository.getCurrent()`, `createStoreWithOwner(...)`; `ProfileRepository.watchAll()`, `create(name, role, pin)`, `update(...)`, `deactivate(id)`, `verifyPin(id, pin)` |
  | categories | `Category` | `watchTree()`, `create(name, parentId?)`, `rename`, `move`, `delete(id)` |
  | products | `Product`, `ProductSummary` (+ stock qty & status), `ProductQuery` | `watch(ProductQuery)`, `getById`, `findByBarcode`, `create(ProductDraft)`, `update`, `archive`, `setImage(id, bytes)` |
  | pricing | `BulkPriceRule`, `PriceChangePreview`, `PriceChange` | `updatePrice(productId, price, cost?)`, `previewBulk(rule)`, `applyBulk(rule) → batchId`, `history(productId)` |
  | stock | `StockLevel`, `StockMovement`, `MovementType`, `MovementInput`, `StockStatus` | `watchLevel(productId)`, `record(MovementInput)`, `movements(productId, range)`, `setReorderPoint(productId, qty)`, `setReorderPointForCategory(categoryId, qty)` |
  | alerts | `StockAlert`, `AlertLevel` | `watchOpen()`, `watchCounts()`, `acknowledge(id)` |
  | dashboard | `DashboardSummary` | `watchSummary()` |
  | import_export | `ImportRow`, `ImportPreview`, `ImportResult` | `parse(bytes)`, `preview(rows)`, `apply(preview)`, `exportProducts()`, `exportMovements(range)` |
  | backup | `BackupInfo` | `create() → bytes`, `restore(bytes)`, `lastBackupAt()` |

- [ ] Stub `presentation/routes.dart` per feature returning a placeholder page with its title
- [ ] **Public surfaces** — each feature gets `lib/features/<f>/public.dart`, the *only* file other features may import from it (besides `domain/`). Stub these agreed symbols so consumers compile from day one:
  - `stock/public.dart` → `StockHistorySection(productId)` widget, `openAlertCountProvider`
  - `backup/public.dart` → `BackupReminderBanner` widget, `backupReminderProvider`
  - `products/public.dart` → `ProductPicker` (search + scan, returns `Product`) — used by stock receive, pricing selection, dashboard
  - `alerts/public.dart` → `AlertBadge` widget
- [ ] **Implementation stubs owned by W1 agents** (so nobody edits `bootstrap.dart`): `lib/core/session/session_impl.dart` (returns `FakeSession`; A1 replaces), `lib/core/platform/impl/platform_providers.dart` (returns fakes; A5 replaces), `lib/core/analytics/impl/analytics_impl.dart` (no-op; A6 replaces). `bootstrap.dart` already points at these.

### 4. Test helpers
- [ ] `test/helpers/test_db.dart` (in-memory `sqflite_common_ffi`, migrations applied), `test_app.dart` (pumps a widget with ProviderScope, brand, theme, locale, direction), `fixtures.dart` (store, branch, owner, staff, 20 products in 3 categories), fakes for every service

### 5. Firebase & deploy baseline
- [ ] Create `shelfwise-dev` / `shelfwise-prod`, one Hosting site per sample brand, minimal `firebase.json` + `.firebaserc` (A7 extends these)

## Acceptance (gate G0)
- [ ] Runs on Android, iOS simulator, Chrome, Windows, macOS; writes + reads a DB row on each
- [ ] `--dart-define=BRAND_ID=demo-green` changes name, logo, colours; light/dark/system; AR shows RTL
- [ ] Every route in `route_paths.dart` opens a placeholder; guards redirect correctly with `FakeSession`
- [ ] All contracts compile; `flutter analyze` clean; core unit tests green
- [ ] A human has reviewed the contracts (they are expensive to change later)
- [ ] Both sample brands live on a Firebase preview channel
