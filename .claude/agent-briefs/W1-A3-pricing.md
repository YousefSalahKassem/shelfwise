# A3 — Pricing (single & bulk)

| | |
|---|---|
| **Wave** | 1 (parallel) · branch `agent/A3-pricing` |
| **Depends on** | G0 only |
| **Owns (code)** | `lib/features/pricing/**` |
| **Owns (tables)** | `products.price_minor`, `products.cost_minor`, `price_changes` |
| **Consumes** | Product & category entities/tables (read), `SessionReader`, `Money` rounding, `AnalyticsService` |
| **Read first** | TECHNICAL_STRUCTURE §6 (money, `price_changes`), PLAN P4 |
| **Business-plan features** | Price management (single edit, bulk by category % / fixed, margin) |

## Goal
An owner reprices a 200-product category in under 2 minutes, with a preview, and every change is recorded.

## Tasks
- [ ] **Single price edit** (sheet opened from product detail via route `/prices/:productId`): new price, optional new cost, live margin % (`(price−cost)/price`), warning if price < cost.
- [ ] **Bulk update** (`/prices/bulk`, owner only): scope = category (incl. sub-categories) or selected products → change = +/− % or +/− fixed amount → apply to price, cost, or both → rounding (none/0.05/0.25/0.50/1.00, round up/nearest) → **preview table** (old, new, margin, flags for below-cost or zero) → confirm.
- [ ] Apply in **one transaction** with `Batch`; write one `price_changes` row per product with shared `batch_id`, `profile_id`; notify `dbChanges`.
- [ ] Batch summary screen: n products changed, average change, "view changes" list.
- [ ] Permission `editPrices` (owner only) checked in the use case; `FeatureLockedFailure` not needed (all tiers).
- [ ] Event: `bulk_price_updated` with props `{count, durationMs, mode}` (duration from screen open to confirm — pilot metric).

## Acceptance
- [ ] +10% with 0.25 rounding on 200 products: preview < 1 s, apply < 2 s on a mid device
- [ ] Rounding and percent math covered by unit tests incl. edge cases (0 price, negative result blocked)
- [ ] Staff calling the use case directly gets `PermissionFailure`
- [ ] Repository test: `price_changes` rows share `batch_id`; products updated atomically (simulate failure mid-batch → nothing changed)
