# B1 — Home dashboard

| | |
|---|---|
| **Wave** | 2 (parallel) · branch `agent/B1-dashboard` |
| **Depends on** | G1 (A1–A7 merged) |
| **Owns (code)** | `lib/features/dashboard/**` |
| **Owns (tables)** | none (read-only across products, stock, alerts, movements, price_changes) |
| **Consumes** | `stock/public.dart`, `alerts/public.dart`, `backup/public.dart`, `products/public.dart`, `SessionReader`, `FeatureFlags` |
| **Read first** | Business plan personas (owner "Karim"), TECHNICAL_STRUCTURE §5 (reactivity), §10 (breakpoints) |
| **Business-plan features** | Home dashboard |

## Goal
The first screen answers "what needs my attention today?" for the owner and "what do I do next?" for staff.

## Tasks
- [ ] `DashboardRepository.watchSummary()` (single SQL pass where possible): low-stock count, out-of-stock count, stock value at cost and at retail (Σ qty × cost/price for non-archived), products count, last 10 changes (movements + price batches merged by time, with who).
- [ ] **Owner layout**: 4 summary tiles (Out, Low, Stock value cost, Stock value retail) → "Needs attention" list (top 5 alerts with receive shortcut) → recent changes → `BackupReminderBanner`.
- [ ] **Staff layout**: big quick actions (Scan / Find product, Receive delivery, Record damage), running-low list; no money totals unless permission `viewCatalogue` + setting "show stock value to staff" (default off).
- [ ] Quick actions for owner: Add product, Receive, Bulk price, Import.
- [ ] Live updates via `dbChanges`; pull-to-refresh on mobile.
- [ ] Empty state for a brand-new store: 3-step checklist (add or import products → set reorder points → record first delivery) — this is the activation path for the pilot metric.
- [ ] Responsive: 1 column compact, 2 columns medium, tiles row + two panels expanded.

## Acceptance
- [ ] Recording a sale that crosses a reorder point updates tiles and list within 300 ms without leaving the screen
- [ ] Values match a hand-computed fixture (repository test)
- [ ] Staff sees no money totals by default
- [ ] Widget tests owner/staff × LTR/RTL; empty-state checklist ticks as steps complete
