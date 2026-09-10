# ShelfWise — Technical Structure

> Companion to [`PLAN.md`](./PLAN.md) and the [ShelfWise business & features plan](https://claude.ai/code/artifact/81eac84a-52d7-4261-a5bd-330b71db7270).
> Scope: the **MVP** (all *Must* features + barcode scanning) built so that *Should* / *Could* features and cloud sync can be added later without re-architecting.
> Status: pre-project design. No code yet.
> Parallel delivery (agent waves, ownership, frozen contracts): [`AGENT_PHASES.md`](./AGENT_PHASES.md).

---

## 1. Stack at a glance

| Concern | Choice | Notes |
|---|---|---|
| UI framework | **Flutter** (stable channel, Dart 3.x) | One codebase: Android, iOS, Web, Windows, macOS (Linux optional) |
| Architecture | **Clean Architecture**, feature-first | `presentation → domain ← data`; domain is pure Dart |
| State management & DI | **Riverpod 3** (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`) | Providers are also the dependency-injection graph |
| Local database | **sqflite** (relational SQLite) | Platform-specific factories — see §6 |
| Routing | `go_router` | URL routing on web, guards for lock screen / roles / tier |
| Models | `freezed` + `json_serializable` | Immutable entities, `copyWith`, unions |
| Localization | `flutter_localizations` + `gen-l10n` (ARB) + `intl` | Arabic (RTL) + English at launch |
| Theming | Material 3 `ThemeData` built from **brand config × light/dark** + `ThemeExtension`s | White-label + multi-theme |
| Web hosting | **Firebase Hosting** (Spark / free plan) | One hosting *site* per brand (up to 36 per project) |
| Local notifications | `flutter_local_notifications` | Low-stock alerts on all platforms incl. web |
| Barcode | `mobile_scanner` (Android, iOS, macOS, Web) | Windows/Linux: USB scanner acting as keyboard |
| Files | `file_picker`, `csv`, `share_plus`, `path_provider` | Import/export, backup |
| Testing | `flutter_test`, `mocktail`, `sqflite_common_ffi` (in-memory DB) | Unit, repository, widget, golden, integration |

Everything above is free and open source. Pin exact versions in `pubspec.lock` at project start (at time of writing: `sqflite` 2.4.x, `sqflite_common_ffi` 2.4.x, `sqflite_common_ffi_web` 1.1.x, `flutter_riverpod` 3.4.x, `riverpod_generator` 4.0.x, `go_router` 18.x, `freezed` 3.x/4.x, `mobile_scanner` 7.x, `flutter_local_notifications` 22.x).

---

## 2. Key architectural decisions (and their consequences)

| # | Decision | Why | Consequence we accept |
|---|---|---|---|
| AD-1 | **Local-first, device-local database (sqflite)** | Free, fast, works offline (poor connectivity in many shops), no backend to run during the prototype | Data lives on one device/browser. No cross-device view, no remote staff, no server push/email. Mitigated by AD-2 and by backup/export. |
| AD-2 | **Sync-ready schema** — UUID primary keys, `created_at` / `updated_at` / `deleted_at` on every table, soft deletes, append-only stock ledger | Lets us add cloud sync later (e.g. Firestore on the same Firebase project) *without* a schema rewrite | Slightly more columns and discipline now |
| AD-3 | **Repository interfaces in domain, data sources behind them** | Swap/add a `RemoteDataSource` later; test domain without a DB | More files per feature |
| AD-4 | **White-label = configuration, never code forks** (business plan: *Won't — per-client custom code*) | One codebase for every brand | Brand differences must be expressible in `brand.json` |
| AD-5 | **One build per brand** selected with `--dart-define=BRAND_ID=<id>` | Each brand gets its own web site, app name, icon and isolated browser storage | CI builds N brands; fine at pilot scale (3 brands) |
| AD-6 | **Tier = feature flags** (`shelf` / `aisle` / `chain`) read from brand config | Matches pricing tiers in the business plan | Every gated feature checks `FeatureFlags` |
| AD-7 | **Money as integer minor units, quantities as integer thousandths** | No floating-point drift in prices or stock (EGP/SAR both have 2 decimals; kg/L need 3) | Formatting helpers required everywhere |
| AD-8 | **Semantic stock colours are fixed, brand colours are not** | Low/out-of-stock must read the same for every brand and in both themes | Brands cannot recolour status indicators |

### What "local database only" means for MVP features

| Business-plan *Must* feature | Local-only implementation in MVP | Full version (needs sync/backend) |
|---|---|---|
| Sign-in & staff invites | Local **profiles** (owner + staff) with PIN on a shared store device | Invite by link, own phone per staff member |
| Low-stock alerts (in-app, push, email) | In-app alert list + **local** notifications | Push (FCM) and email to the owner's phone |
| Reseller console | **Brand Studio**: web tool that edits `brand.json` (name, logo, colours, tier) with live preview | Create/suspend stores, usage per store |
| Multi-tenant data isolation | Per-device DB; per-brand browser origin on web; every row scoped by `store_id` | Row-level rules on the server |
| Owner sees stock remotely | Not possible — owner uses the store device or the web app on the same browser | Synced data on any device |

These gaps are tracked as **open decision OD-1** in `PLAN.md`.

---

## 3. Clean Architecture

```
┌──────────────────────── presentation ────────────────────────┐
│ Pages · Widgets · Riverpod Notifiers/AsyncNotifiers           │
│ (knows Flutter, Riverpod, go_router, l10n, theme)             │
└───────────────┬───────────────────────────────────────────────┘
                │ calls use cases, reads entities
┌───────────────▼──────────────── domain (pure Dart) ───────────┐
│ Entities · Value objects · Repository interfaces · Use cases  │
│ Failures · Result<T> · Permissions · FeatureFlags             │
└───────────────▲───────────────────────────────────────────────┘
                │ implements interfaces
┌───────────────┴──────────────── data ─────────────────────────┐
│ Repository impls · Local data sources (DAOs over sqflite)     │
│ Models/row mappers · (later) Remote data sources + sync        │
└───────────────────────────────────────────────────────────────┘
```

**Rules**

1. `domain/` imports nothing from Flutter, sqflite, Riverpod or `data/`. (Enforce with an import-lint rule or a CI `grep`.)
2. `presentation/` never touches a DAO or SQL; it calls **use cases**.
3. `data/` converts DB rows ⇄ entities in **mappers**; entities never carry DB column names.
4. Errors cross layers as `Result<T>` (`Success` / `Failure`), not thrown exceptions. Data sources may throw; repositories catch and map to `Failure`.
5. One use case = one user intention (`ReceiveStock`, `BulkUpdatePrices`), usually one DB transaction.
6. Features don't import each other's `data/` or `presentation/`. Cross-feature needs go through the other feature's `domain/` interfaces or its `public.dart` (a small, agreed set of widgets/providers).

### Result & failures (core/error)

```dart
sealed class Result<T> { const Result(); }
final class Success<T> extends Result<T> { const Success(this.value); final T value; }
final class Err<T> extends Result<T> { const Err(this.failure); final Failure failure; }

sealed class Failure { const Failure(); }
final class ValidationFailure extends Failure { /* field → l10n key */ }
final class NotFoundFailure extends Failure {}
final class ConflictFailure extends Failure {}      // e.g. duplicate barcode
final class PermissionFailure extends Failure {}    // role not allowed
final class FeatureLockedFailure extends Failure {} // tier doesn't include it
final class StorageFailure extends Failure {}       // DB / file errors
```

Failures carry **l10n keys**, never user-facing strings, so messages translate.

---

## 4. Project structure

```
shelfwise/
├── android/ ios/ web/ windows/ macos/ (linux/)
├── assets/
│   ├── brands/
│   │   ├── shelfwise/            # house/demo brand
│   │   │   ├── brand.json
│   │   │   ├── logo.png  logo_dark.png  icon.png
│   │   └── <brand_id>/ …         # one folder per white-label client
│   ├── fonts/                    # bundled (no runtime font download; works offline)
│   └── seed/                     # demo catalogues (mini-market, pharmacy) for sales demos
├── lib/
│   ├── main.dart                 # reads BRAND_ID, calls bootstrap()
│   ├── bootstrap.dart            # init DB factory, load brand, ProviderScope overrides
│   ├── app.dart                  # MaterialApp.router: theme, darkTheme, themeMode, locale
│   ├── core/
│   │   ├── brand/                # BrandConfig, BrandLoader, Tier, FeatureFlags
│   │   ├── database/
│   │   │   ├── app_database.dart         # open, onConfigure, onCreate, onUpgrade
│   │   │   ├── db_factory.dart           # conditional export (§6)
│   │   │   ├── db_factory_io.dart
│   │   │   ├── db_factory_web.dart
│   │   │   ├── schema/                   # table & column name constants
│   │   │   └── migrations/               # m001_initial.dart, m002_….dart
│   │   ├── analytics/            # AppEvent enum, AnalyticsService (+ impl/)
│   │   ├── auth/                 # Role, Permission, default role matrix
│   │   ├── error/                # Result, Failure, exceptions
│   │   ├── l10n/
│   │   │   ├── common_en.arb  common_ar.arb
│   │   │   ├── arb/              # app_en.arb, app_ar.arb — generated by tools/scripts/merge_arb.dart, committed
│   │   │   └── gen/              # AppLocalizations — generated by gen-l10n, git-ignored
│   │   ├── router/               # app_router.dart, routes.dart, guards.dart
│   │   ├── theme/                # app_theme.dart, stock_colors.dart, spacing.dart, typography.dart
│   │   ├── platform/             # NotificationService, ScannerService, FileService (+ per-platform impls)
│   │   ├── session/              # current store, current profile, lock state
│   │   ├── utils/                # money.dart, quantity.dart, ids.dart, clock.dart, debouncer.dart
│   │   └── widgets/              # AppScaffold (responsive), MoneyText, StockBadge, EmptyState…
│   └── features/
│       ├── onboarding/           # first run: create store, currency, owner profile
│       ├── profiles/             # owner/staff profiles, PIN lock, roles
│       ├── dashboard/
│       ├── categories/
│       ├── products/
│       ├── pricing/              # single + bulk price updates, rounding
│       ├── stock/                # levels, movements, reorder points, stock count (Should)
│       ├── alerts/               # low-stock detection + list + notifications
│       ├── import_export/        # CSV import/export
│       ├── backup/               # full backup/restore, pilot usage export
│       └── settings/             # theme mode, language, digits, about brand
│       # every feature also has: l10n/<feature>_{en,ar}.arb and public.dart (its only cross-feature surface)
│       # later: branches/, suppliers/, reports/, activity_log/, sync/
├── tools/
│   ├── brand_studio/             # small Flutter web app: edit brand.json with live preview
│   └── scripts/                  # build_brand.sh, deploy_brand.sh, seed_db.dart
├── test/ integration_test/
├── l10n.yaml  analysis_options.yaml  build.yaml  firebase.json  .firebaserc
└── pubspec.yaml
```

### Inside one feature (example: `products`)

```
features/products/
├── domain/
│   ├── entities/product.dart               # @freezed Product
│   ├── value_objects/barcode.dart, sku.dart
│   ├── repositories/product_repository.dart   # abstract interface
│   └── usecases/
│       ├── create_product.dart
│       ├── update_product.dart
│       ├── archive_product.dart
│       ├── get_products.dart                   # search, filter, paging
│       └── find_product_by_barcode.dart
├── data/
│   ├── datasources/product_local_data_source.dart   # SQL lives only here
│   ├── models/product_row.dart                      # Map<String,Object?> ⇄ ProductRow
│   ├── mappers/product_mapper.dart                  # ProductRow ⇄ Product
│   └── repositories/product_repository_impl.dart
└── presentation/
    ├── providers/                  # @riverpod controllers, filters, form state
    ├── pages/product_list_page.dart, product_form_page.dart, product_detail_page.dart
    └── widgets/product_tile.dart, price_field.dart, barcode_field.dart
```

---

## 5. Riverpod: state management & dependency injection

Use **code generation** (`@riverpod`) everywhere for consistency.

### Provider graph

```
databaseProvider (AppDatabase, overridden in bootstrap)
   └── productLocalDataSourceProvider
          └── productRepositoryProvider      (returns the domain interface)
                 └── createProductProvider   (use case)
                        └── ProductFormController (Notifier)  ← UI

brandConfigProvider (overridden in bootstrap) → featureFlagsProvider → themeProvider
sessionProvider (current store + profile)     → permissionsProvider
settingsProvider (themeMode, locale, digits)  → app.dart
clockProvider, idGeneratorProvider            → overridable in tests
```

### Conventions

| Need | Provider type |
|---|---|
| Singletons (DB, repositories, services) | `@Riverpod(keepAlive: true)` function provider |
| Read-only query (product list, dashboard numbers) | `@riverpod Future<T>` / `Stream<T>` (auto-dispose) |
| Screen/form state with actions | `@riverpod class XController extends _$XController` (Notifier / AsyncNotifier) |
| Parameterised queries | family via function parameters (`productProvider(id)`) |
| Filters/search | small Notifier; list provider `ref.watch`es it |

- **Reactivity after writes:** repositories expose a lightweight change signal (`dbChangesProvider` — a `StreamController<Set<String>>` of touched tables). Query providers watch it and refresh when their table changes, so the dashboard and low-stock list update instantly after a stock movement.
- UI handles `AsyncValue` with `switch` (loading / error / data); errors show the translated `Failure`.
- Tests use `ProviderContainer(overrides: [...])` with an in-memory DB, fixed clock and fixed brand.

---

## 6. Local database (sqflite) across platforms

### Platform matrix

| Platform | Package / factory | Storage | Notes |
|---|---|---|---|
| Android, iOS, macOS | `sqflite` (default `databaseFactory`) | App documents dir | Native SQLite |
| Windows, Linux | `sqflite_common_ffi` → `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;` | App support dir | Linux needs `libsqlite3` / `libsqlite3-dev` |
| Web | `sqflite_common_ffi_web` → `databaseFactoryFfiWeb` | IndexedDB (per origin) | **Experimental**: slower, some bugs (e.g. `deleteDatabase`); requires `dart run sqflite_common_ffi_web:setup` which adds `web/sqlite3.wasm` and `web/sqflite_sw.js` (commit both) |
| Unit tests | `sqflite_common_ffi` with `inMemoryDatabasePath` | Memory | Fast, no emulator |

### Factory selection (conditional import)

```dart
// core/database/db_factory.dart
export 'db_factory_stub.dart'
    if (dart.library.io) 'db_factory_io.dart'
    if (dart.library.js_interop) 'db_factory_web.dart';

// db_factory_io.dart
Future<DatabaseFactory> createDatabaseFactory() async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return sqflite.databaseFactory; // Android, iOS, macOS
}

// db_factory_web.dart
Future<DatabaseFactory> createDatabaseFactory() async => databaseFactoryFfiWeb;
```

`AppDatabase` receives the factory — it never checks the platform itself.

### Web-specific rules

- Each brand is served from its own Firebase Hosting site ⇒ its own origin ⇒ **isolated IndexedDB** per brand automatically.
- Browser storage can be cleared by the user or the browser. Mitigations: prominent **Backup** (download JSON), a reminder after N days without backup, `navigator.storage.persist()` request on first run.
- Local dev: the DB is tied to the port (`localhost:8080` ≠ `localhost:8081`). Always run web on a fixed port.
- Older browsers without SharedWorker (e.g. some Android Chrome) are less safe with several tabs open ⇒ show a "ShelfWise is open in another tab" notice.

### Database conventions

- `PRAGMA foreign_keys = ON` in `onConfigure`.
- **IDs:** UUID v4 strings (`TEXT PRIMARY KEY`) generated in Dart via `idGeneratorProvider`.
- **Timestamps:** `INTEGER` epoch milliseconds UTC: `created_at`, `updated_at`, nullable `deleted_at` (soft delete).
- **Money:** `INTEGER` minor units (`price_minor = 1250` → 12.50). Currency is a store setting (`EGP`, `SAR`).
- **Quantity:** `INTEGER` thousandths (`qty_milli = 2500` → 2.5 kg; pieces are ×1000).
- **Writes that touch several tables run in one `transaction`** (e.g. movement + level + alert). sqflite transactions are exclusive — keep them short; use `Batch` for imports.
- **Migrations:** ordered list `m001_initial`, `m002_…`; `onCreate` runs all, `onUpgrade(old,new)` runs `old+1..new`. Never edit a shipped migration.

### Schema v1 (MVP)

```sql
-- every table also has: created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER

stores        (id TEXT PK, name TEXT NOT NULL, currency TEXT NOT NULL, locale TEXT NOT NULL)
branches      (id TEXT PK, store_id TEXT NOT NULL REFERENCES stores(id), name TEXT NOT NULL,
               is_default INTEGER NOT NULL DEFAULT 0)
               -- MVP creates exactly one default branch; multi-branch (Should) needs no migration

profiles      (id TEXT PK, store_id TEXT NOT NULL REFERENCES stores(id), name TEXT NOT NULL,
               role TEXT NOT NULL CHECK (role IN ('owner','staff')),
               pin_hash TEXT NOT NULL, pin_salt TEXT NOT NULL,
               locale TEXT, is_active INTEGER NOT NULL DEFAULT 1)

categories    (id TEXT PK, store_id TEXT NOT NULL, parent_id TEXT REFERENCES categories(id),
               name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0)
               -- max depth 2 enforced in the use case (e.g. Dairy › Cheese)

products      (id TEXT PK, store_id TEXT NOT NULL, category_id TEXT REFERENCES categories(id),
               name TEXT NOT NULL, name_alt TEXT,             -- optional second-language name
               sku TEXT, barcode TEXT, unit TEXT NOT NULL DEFAULT 'piece',  -- piece|kg|g|l|ml|box|pack
               cost_minor INTEGER NOT NULL DEFAULT 0, price_minor INTEGER NOT NULL,
               reorder_point_milli INTEGER NOT NULL DEFAULT 0,
               is_archived INTEGER NOT NULL DEFAULT 0)

product_images(product_id TEXT PK REFERENCES products(id), thumb BLOB NOT NULL, mime TEXT NOT NULL)
               -- stored as compressed BLOB (≤ ~60 KB) so images work on web too (no file paths there)

stock_levels  (product_id TEXT NOT NULL, branch_id TEXT NOT NULL,
               qty_milli INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (product_id, branch_id))
               -- cached current quantity; always updated in the same transaction as a movement

stock_movements (id TEXT PK, product_id TEXT NOT NULL, branch_id TEXT NOT NULL,
               type TEXT NOT NULL CHECK (type IN ('receive','sale','damaged','expired',
                                                  'adjustment','count','transfer_in','transfer_out')),
               qty_delta_milli INTEGER NOT NULL, qty_after_milli INTEGER NOT NULL,
               unit_cost_minor INTEGER, note TEXT, profile_id TEXT NOT NULL REFERENCES profiles(id))
               -- append-only ledger: never updated or deleted

price_changes (id TEXT PK, product_id TEXT NOT NULL, old_price_minor INTEGER NOT NULL,
               new_price_minor INTEGER NOT NULL, old_cost_minor INTEGER, new_cost_minor INTEGER,
               batch_id TEXT, profile_id TEXT NOT NULL)
               -- batch_id groups a bulk update so it can be reviewed (and later undone)

stock_alerts  (id TEXT PK, product_id TEXT NOT NULL, branch_id TEXT NOT NULL,
               level TEXT NOT NULL CHECK (level IN ('low','out')),
               triggered_at INTEGER NOT NULL, resolved_at INTEGER, acknowledged_at INTEGER)

app_events    (id TEXT PK, name TEXT NOT NULL, props TEXT, profile_id TEXT)
               -- local analytics for pilot metrics (§11); exportable

settings      (key TEXT PK, value TEXT NOT NULL)   -- theme_mode, locale, digits, last_backup_at…
```

**Indexes:** `products(store_id, barcode)` UNIQUE where barcode not null; `products(store_id, sku)`; `products(store_id, category_id)`; `products(store_id, name COLLATE NOCASE)`; `stock_movements(product_id, created_at)`; `stock_alerts(resolved_at)`.

**Low-stock query:** `qty_milli <= reorder_point_milli AND reorder_point_milli > 0` (low) / `qty_milli <= 0` (out). Checked inside the `RecordStockMovement` use case transaction; opens or resolves a `stock_alerts` row and, on a new alert, fires a local notification.

Target performance: 5,000 products, 100,000 movements; product search < 150 ms on a low-end Android phone. Seed script in `tools/scripts/seed_db.dart`.

---

## 7. White-label (brand) system

### `brand.json`

```json
{
  "id": "acme",
  "appName": "Acme Stock",
  "tier": "shelf",
  "colors": { "primary": "#0D6A56", "secondary": "#A86F00", "useDynamicSeed": true },
  "logo": "assets/brands/acme/logo.png",
  "logoDark": "assets/brands/acme/logo_dark.png",
  "defaultLocale": "ar",
  "supportedLocales": ["ar", "en"],
  "defaultCurrency": "EGP",
  "support": { "phone": "+20…", "whatsapp": "+20…", "email": "help@acme.example" },
  "legal": { "companyName": "Acme Tech LLC", "privacyUrl": "https://…" }
}
```

- `main.dart` reads `const String.fromEnvironment('BRAND_ID', defaultValue: 'shelfwise')`, `BrandLoader` loads `assets/brands/<id>/brand.json` and validates it (bad config fails the build script, not the user).
- `brandConfigProvider` is overridden in `bootstrap.dart`; everything else reads it.
- **Tier → `FeatureFlags`** (single source of truth, in `core/brand/feature_flags.dart`):

| Flag | shelf | aisle | chain |
|---|---|---|---|
| core catalogue, prices, stock, low-stock alerts, CSV, scanning, AR/EN | ✓ | ✓ | ✓ |
| `maxStaffProfiles` | 3 | ∞ | ∞ |
| `activityLog` | – | ✓ | ✓ |
| `multiBranch`, `suppliers`, `expiryDates`, `customRoles`, `advancedReports` | – | ✓ | ✓ |
| `hqMasterCatalogue`, `api`, `sso` | – | – | ✓ |

- Gated UI is **hidden**; gated use cases return `FeatureLockedFailure` (defence in depth).
- **Brand Studio** (`tools/brand_studio/`): a small Flutter web app (deployed as its own Firebase site) that edits a `brand.json`, previews the app in light/dark/AR/EN, and exports the brand folder. This covers the business-plan "*your logo in 10 minutes*" sales demo and replaces the reseller console until sync exists.
- **Native per-brand identity (later, Aisle tier):** Android `productFlavors` / iOS schemes for application ID, app name and launcher icon (`flutter_launcher_icons`, `flutter_native_splash` per flavor). The MVP ships the web app + one Android APK per brand via `--dart-define`.

---

## 8. Multi-theme

Theme = **brand palette** × **mode (light / dark / system)** × **text direction**.

```dart
ThemeData buildTheme(BrandConfig brand, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brand.colors.primary,
    secondary: brand.colors.secondary,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: AppTypography.forLocale(...),
    extensions: [StockColors.of(brightness), AppSpacing.standard],
  );
}
```

- `app.dart`: `theme: buildTheme(brand, light)`, `darkTheme: buildTheme(brand, dark)`, `themeMode: settings.themeMode` (persisted in `settings`).
- **`ThemeExtension`**: `StockColors` (ok / low / out — fixed, WCAG AA in both modes, AD-8). `AppSpacing`, `AppRadii`, `Breakpoints` are plain constants. Widgets read `Theme.of(context).extension<StockColors>()!` — never hard-coded colours.
- **Contrast guard:** `BrandLoader` checks brand primary vs. surface contrast in both modes and nudges tone if below 4.5:1 (log a warning in Brand Studio).
- **Fonts:** bundled in `assets/fonts` (no runtime download; works offline): *IBM Plex Sans Arabic*, which covers Arabic and Latin, so one family serves both languages (`AppTypography`).
- **Golden tests:** every key screen × {2 brands} × {light, dark} × {en-LTR, ar-RTL}.

---

## 9. Multi-localization

- **Per-feature ARB fragments** (`lib/features/<f>/l10n/<f>_{en,ar}.arb`, keys prefixed by feature) are merged by `tools/scripts/merge_arb.dart` into `lib/core/l10n/arb/app_{en,ar}.arb`, then `flutter gen-l10n` runs. This lets parallel agents add strings without editing a shared file.
- `l10n.yaml`:
  ```yaml
  arb-dir: lib/core/l10n/arb
  template-arb-file: app_en.arb
  output-dir: lib/core/l10n/gen
  output-localization-file: app_localizations.dart
  nullable-getter: false
  ```
- `MaterialApp.router(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: brand.supportedLocales)`.
- **Locale priority:** profile locale → store locale → brand default → device locale.
- **RTL correctness:** use `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `start`/`end` everywhere; icons that imply direction (back, chevrons) mirror automatically or via `Directionality`. Add a lint/grep for `EdgeInsets.only(left:` / `right:`.
- **Numbers & money:** `intl` `NumberFormat.currency(locale:, name: currency)`; setting to choose Arabic-Indic (٠١٢) or Latin (012) digits — many shops prefer Latin digits even in Arabic UI; default per brand.
- **Brand name in strings:** ARB placeholders (`"welcome": "Welcome to {appName}"`) — never hard-code "ShelfWise" in UI.
- **User data isn't translated:** product names are entered by the store; `name_alt` allows an optional second-language name for search.
- **Adding a language** = add `app_xx.arb` + add `xx` to the brand's `supportedLocales`. No code change.
- CI fails if any key is missing in a non-template ARB (`untranslated-messages-file` must be empty).

---

## 10. Navigation, roles & responsive layout

**Routes (go_router)**

```
/onboarding                 first run only
/lock                       choose profile + PIN
/                           ShellRoute (bottom nav on compact, NavigationRail on medium+)
  /dashboard
  /products        /products/new   /products/:id   /products/:id/edit
  /categories
  /stock           /stock/receive  /stock/adjust   /stock/count (Should)
  /alerts
  /prices/bulk
  /settings        /settings/profiles  /settings/backup  /settings/import
```

**Guards (redirect):** no store → `/onboarding`; locked/idle > N min → `/lock`; route needs permission the role lacks → `/dashboard` with a message; route needs a tier flag → hidden from nav + redirect.

**Permissions (domain)**

| Action | Owner | Staff |
|---|---|---|
| View products, prices, stock | ✓ | ✓ |
| Receive / adjust stock, record sale/damage | ✓ | ✓ |
| Create / edit products & categories | ✓ | configurable (default ✗) |
| Change prices (single / bulk) | ✓ | ✗ |
| Manage profiles, import/export, backup, settings | ✓ | ✗ |

**Breakpoints:** compact < 600 dp (phone), medium 600–1024 (tablet / small web), expanded > 1024 (desktop web, Windows). List/detail side-by-side on expanded.

---

## 11. Platform services (behind interfaces in `core/platform`)

| Service | Interface | Implementations |
|---|---|---|
| Notifications | `NotificationService.showLowStock(...)` | `flutter_local_notifications` (Android, iOS, macOS, Windows, Linux, Web Notifications API — permission asked only after a user tap) |
| Barcode | `ScannerService.scan()` | `mobile_scanner` on Android/iOS/macOS/Web; on Windows/Linux a focused text field that accepts **USB/Bluetooth scanner input** (they type like a keyboard + Enter) |
| Files | `FileService.pick()/save()/share()` | `file_picker`, `share_plus` (mobile), browser download (web) |
| Analytics (pilot metrics) | `AnalyticsService.log(event, props)` | Writes to `app_events`; exportable. Optionally mirrored to Firebase Analytics later (free) — see OD-4 |

Pilot events: `store_created`, `product_created`, `reorder_point_set`, `stock_movement_recorded`, `bulk_price_updated`, `low_stock_alert_fired`, `alert_opened`, `profile_switched`, `session_started`, `import_completed`, `backup_created`. These feed the activation/retention metrics in business plan §9.

---

## 12. Import, export & backup

- **CSV import** (template downloadable in-app, AR/EN headers): `name, name_alt, category, subcategory, sku, barcode, unit, cost, price, quantity, reorder_point`.
  Flow: pick file → parse (isolate/`compute` for large files) → **preview with row-level errors** (duplicate barcode, bad price) → confirm → `Batch` insert in one transaction → summary. Categories auto-created by name.
- **CSV export:** products with current stock and value; movements for a date range.
- **Full backup/restore:** single JSON file of all tables (+ schema version) — the only safety net for web storage and device loss. Restore validates schema version and runs migrations.
- `.xlsx` import (via `excel` package) is a *Should* — CSV first ("Save as CSV" from Excel).

---

## 13. Build, environments & Firebase Hosting

**Environments:** two free Firebase projects — `shelfwise-dev` and `shelfwise-prod` (Firebase recommends separate projects per environment rather than extra sites).

**Sites:** one Hosting site per brand in each project (max 36 per project): `acme-shelfwise.web.app`, later a custom domain on Aisle tier. Plus `brand-studio` site.

```bash
# one-time per brand
firebase hosting:sites:create acme-shelfwise
firebase target:apply hosting acme acme-shelfwise

# build + deploy a brand (tools/scripts/deploy_brand.sh acme)
flutter build web --release --dart-define=BRAND_ID=acme --dart-define=ENV=prod
rm -rf dist/acme && cp -r build/web dist/acme
firebase deploy --only hosting:acme
# preview channel for pilot testing
firebase hosting:channel:deploy pilot --only acme
```

```json
// firebase.json (one entry per brand)
{
  "hosting": [
    {
      "target": "acme",
      "public": "dist/acme",
      "ignore": ["firebase.json", "**/.*"],
      "rewrites": [{ "source": "**", "destination": "/index.html" }],
      "headers": [
        { "source": "**/*.wasm", "headers": [{ "key": "Content-Type", "value": "application/wasm" }] },
        { "source": "/index.html", "headers": [{ "key": "Cache-Control", "value": "no-cache" }] },
        { "source": "**/*.@(js|wasm|png|ttf|otf)", "headers": [{ "key": "Cache-Control", "value": "max-age=604800" }] }
      ]
    }
  ]
}
```

- Web app is installable (PWA manifest per brand generated by the build script: name, colours, icons).
- **Android:** `flutter build apk --release --dart-define=BRAND_ID=acme` → APK shared directly for the pilot (Play Store listing later; one-time $25 fee is not free).
- **iOS:** buildable, but distribution needs a paid Apple developer account ($99/yr) → not in the pilot.
- **Windows/macOS:** `flutter build windows|macos` for counter PCs if a pilot store needs it.
- **CI (optional, free tier):** GitHub Actions — `analyze → test → build web (per brand) → deploy preview channel` on PR; deploy prod on tag.

---

## 14. Testing strategy

| Level | What | Tools | Target |
|---|---|---|---|
| Unit | Use cases, value objects, money/qty math, rounding, permissions, feature flags | `test`, `mocktail` | ≥ 90% of `domain/` |
| Repository | Real SQL against in-memory DB, migrations up from v1 | `sqflite_common_ffi` + `inMemoryDatabasePath` | Every DAO + every migration |
| Widget | Forms, validation, gated UI, RTL layout | `flutter_test`, `ProviderScope` overrides | Key screens |
| Golden | Themes × brands × LTR/RTL | `matchesGoldenFile` | Dashboard, product list, product form, alerts |
| Integration | *Add product → receive 10 → sell 8 → low-stock alert → bulk +10% price → export CSV* | `integration_test` on Android + Chrome | Before each pilot build |
| Manual | Web on Chrome/Edge/Safari, low-end Android, Windows + USB scanner | checklist | Before each pilot build |

---

## 15. Code quality & conventions

- Lints: `flutter_lints` + strict analyzer settings; `dart format` enforced in CI. (`riverpod_lint` left out in W0: its analyzer pin conflicts with `riverpod_generator` 4.0.9 — re-add when compatible.)
- Codegen: `dart run build_runner watch -d`; generated files (`*.g.dart`, `*.freezed.dart`) committed or regenerated in CI — decide once (recommend: not committed, CI regenerates).
- Naming: `snake_case` files, one public class per file, use cases named as verbs (`ReceiveStock`).
- No `print`; a small `AppLogger` (debug only).
- No business logic in widgets; no `BuildContext` in domain; no SQL outside `data/datasources`.
- Git: `main` (always deployable) + short-lived `feat/…` branches, PR review, Conventional Commits.
- Security (local): PINs hashed with salt (PBKDF2/SHA-256 via `crypto`), app lock on idle, no secrets in the repo (Firebase config for Hosting only).
