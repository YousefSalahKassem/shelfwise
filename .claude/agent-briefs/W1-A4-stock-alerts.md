# A4 — Stock movements & low-stock alerts

| | |
|---|---|
| **Wave** | 1 (parallel) · branch `agent/A4-stock` |
| **Depends on** | G0 only |
| **Owns (code)** | `lib/features/stock/**`, `lib/features/alerts/**` |
| **Owns (tables)** | `products.reorder_point_milli`, `stock_levels`, `stock_movements`, `stock_alerts` |
| **Consumes** | `NotificationService`, `ScannerService` (fakes until A5), product entities (read), `SessionReader`, `AnalyticsService` |
| **Read first** | TECHNICAL_STRUCTURE §6 (ledger, low-stock query), PLAN P5 |
| **Business-plan features** | Stock levels & movements, Low-stock alerts (logic, in-app list, local notification trigger), reorder points |

## Goal
Every stock change is a ledger entry, current levels are always right, and the owner is warned before best-sellers run out.

## Tasks
- [ ] **`RecordStockMovement`** use case — one transaction: validate → insert `stock_movements` (`qty_after_milli`) → upsert `stock_levels` → evaluate alert (open `low`/`out`, escalate low→out, resolve when back above reorder point) → `dbChanges` → if a new alert opened, call `NotificationService.showLowStock` **after** commit. Types: receive, sale, damaged, expired, adjustment (+/−). Negative stock allowed only for `adjustment` with a confirm; otherwise `ValidationFailure`.
- [ ] **Receive delivery** (`/stock/receive`): scan-first loop (scan → qty → next), manual search via `ProductPicker` from `products/public.dart`, optional unit cost per line, running list, "finish" commits all lines in one transaction. Target: 30 items < 5 min.
- [ ] **Quick adjust** (`/stock/adjust` and from product detail): type + qty + note.
- [ ] **Reorder points**: per product (detail) and bulk per category (`setReorderPointForCategory`). Permission `setReorderPoints` (owner). Event `reorder_point_set`.
- [ ] **Stock history widget** for product detail (`StockHistorySection(productId)`) exported from `stock/public.dart` (replace W0 stub) — timeline of movements with who/when/why.
- [ ] **Alerts** (`/alerts`): open alerts grouped Out → Low, each with product, qty, reorder point, "receive stock" shortcut, acknowledge. `openAlertCountProvider` (in `stock/public.dart`) and `AlertBadge` (in `alerts/public.dart`) for the nav. Events `low_stock_alert_fired`, `alert_opened`.
- [ ] Permissions: `recordStock` and `adjustStock` (owner **and** staff — business plan: staff can receive and adjust stock; owner-only: `setReorderPoints`).

## Acceptance
- [ ] Reorder point 3, receive 10, sell 8 → one `low` alert + one notification; sell 2 more → escalates to `out` (no duplicate notification spam: max one per product per level); receive 5 → alert resolved
- [ ] Ledger sum of `qty_delta_milli` always equals `stock_levels.qty_milli` (property test over random sequences)
- [ ] Failure mid-transaction leaves no partial movement/level
- [ ] Widget tests: receive flow (LTR+RTL), alerts list
