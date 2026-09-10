# B2 — CSV import & export

| | |
|---|---|
| **Wave** | 2 (parallel) · branch `agent/B2-import` |
| **Depends on** | G1 |
| **Owns (code)** | `lib/features/import_export/**` |
| **Owns (tables)** | none directly — writes **through** category, product, pricing and stock repositories (add bulk methods via change request if needed, or call in a batch transaction the owners expose) |
| **Consumes** | `FileService`, category/product/stock repository interfaces, `Money`, `Quantity`, `AnalyticsService` |
| **Read first** | TECHNICAL_STRUCTURE §12; business plan GTM ("we set it up for you" day) |
| **Business-plan features** | CSV/Excel import & export (CSV part) |

## Goal
A store's existing Excel list (saved as CSV) becomes a working catalogue with opening stock in minutes, with clear errors instead of silent failures.

## Tasks
- [ ] **Template download** with AR and EN headers: `name, name_alt, category, subcategory, sku, barcode, unit, cost, price, quantity, reorder_point`; header matching is case-insensitive and accepts either language.
- [ ] **Parse** off the UI thread (`compute`/isolate); detect delimiter (`,` `;` tab) and UTF-8 with/without BOM (Excel Arabic exports).
- [ ] **Preview** (`/settings/import`): counts (new / update-by-barcode-or-SKU / errors), row-level errors (missing name/price, bad number, duplicate barcode in file or DB, unknown unit), toggle "update existing products", download error report CSV.
- [ ] **Apply** in one transaction: create missing categories → products → opening stock as `receive` movements (note "Import") → reorder points. Uses `Batch`. Logs `import_completed {rows, created, updated, errors, durationMs}`.
- [ ] **Export**: products (with current qty, status, stock value) and movements for a date range; filename includes brand + store + date.
- [ ] Permission `importExport` (owner).

> Cross-feature writes: B2 must not write SQL against A2/A3/A4 tables. If the existing repositories lack a bulk method, raise a change request; the lead or owner adds e.g. `ProductRepository.createMany(...)` accepting a transaction handle. Until then, B2 may wrap single-item calls in one transaction.

## Acceptance
- [ ] 1,000-row real-world CSV (Arabic names, Excel-exported) imports in < 10 s on a mid device with correct counts
- [ ] Any single failing row does not block others (skipped with error) unless the user chooses "all or nothing"
- [ ] Re-importing the same file with "update existing" changes nothing except updated fields
- [ ] Export → import round-trip reproduces the catalogue
