# A2 — Catalogue: categories, products & search

| | |
|---|---|
| **Wave** | 1 (parallel) · branch `agent/A2-catalogue` |
| **Depends on** | G0 only |
| **Owns (code)** | `lib/features/categories/**`, `lib/features/products/**` |
| **Owns (tables)** | `categories`; `products` except `price_minor`, `cost_minor`, `reorder_point_milli` (initial values on create are allowed); `product_images` |
| **Consumes** | `ScannerService` (fake until A5 merges), `SessionReader`, `StockStatus` from stock domain (read `stock_levels` for list badges), `AnalyticsService` |
| **Read first** | TECHNICAL_STRUCTURE §3, §4 (products example), §5, §6 |
| **Business-plan features** | Products, Categories, Search & filters, barcode find/new (flow) |

## Goal
Owners build and browse a catalogue of 5,000+ products quickly; staff find any product and its price in seconds.

## Tasks
- [ ] **Categories** (`/categories`): two-level tree, create/rename/reorder/move; delete only when empty (or offer "move products to…"). Max depth 2 enforced in the use case.
- [ ] **Product form** (`/products/new`, `/products/:id/edit`): name, name_alt, category, SKU, barcode (scan button), unit (piece/kg/g/l/ml/box/pack), cost, price (initial), photo. Validation: required name + price, price ≥ 0, unique barcode and SKU per store (`ConflictFailure`), quantity decimals only for weight/volume units.
- [ ] **Photo**: pick/take → resize to ≤ 400 px, JPEG ~70% → `product_images.thumb` BLOB (works on web).
- [ ] **Product list** (`/products`): search name/name_alt/SKU/barcode (debounced 250 ms), filter by category and stock status (ok/low/out from `stock_levels` + reorder point), sort (name, recently updated), paging (50/page, infinite scroll). Reacts to `dbChanges` on products and stock tables.
- [ ] **Product detail** (`/products/:id`): info, price & margin, current stock (read-only), stock history via `StockHistorySection(productId)` from `stock/public.dart` (W0 stub until A4 merges).
- [ ] **Archive/unarchive** (hidden from lists, kept for history).
- [ ] **Barcode flows**: from list → scan → found: open detail · not found: open new form prefilled with barcode. Keyboard-wedge: a focused search field accepts scanner input ending with Enter.
- [ ] **`ProductPicker`** in `products/public.dart` (replace W0 stub): search + scan, returns a `Product`; used by stock, pricing and dashboard.
- [ ] Permissions: `editCatalogue` for create/edit/archive; everyone can view.
- [ ] Events: `product_created`.

## Acceptance
- [ ] Duplicate barcode shows a translated error on the field
- [ ] 5,000 seeded products: first page < 300 ms, search < 150 ms on a mid device (B3 re-checks on low-end)
- [ ] Image appears on Android and Chrome after restart
- [ ] Unit tests (validation, depth rule), repository tests (search, filters, paging, uniqueness), widget tests (form LTR+RTL, list filters)
