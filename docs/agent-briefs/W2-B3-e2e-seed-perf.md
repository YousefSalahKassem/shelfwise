# B3 — E2E tests, seed data & performance

| | |
|---|---|
| **Wave** | 2 (parallel) · branch `agent/B3-e2e` |
| **Depends on** | G1 |
| **Owns (code)** | `integration_test/**`, `tools/scripts/seed_db.dart`, `assets/seed/**`, `test/perf/**` |
| **Owns (tables)** | none (seed writes go through repositories in a debug-only entry point) |
| **Read first** | TECHNICAL_STRUCTURE §6 (performance target), §14; PLAN §8 |

## Goal
Prove the MVP works end to end on real devices and stays fast with a full-size catalogue.

## Tasks
- [ ] **Seed catalogues**: mini-market (~1,800 SKUs, 12 categories) and pharmacy (~2,500 SKUs), realistic Arabic + English names, units, prices in EGP and SAR; plus a 5,000-SKU stress set and 100,000 synthetic movements. Debug-only menu item "Load demo catalogue" (used for sales demos too).
- [ ] **E2E scenario** (`integration_test/mvp_flow_test.dart`): onboarding → add product (scan mocked) → receive 10 → sell 8 with reorder point 3 → alert + dashboard update → bulk +10% price on category → export CSV → backup → restore → verify. Run on Android emulator and Chrome (`flutter drive`).
- [ ] **Role scenario**: staff profile cannot reach pricing/profiles by UI or URL.
- [ ] **Perf tests**: search, list first page, dashboard summary, receive 30 items — timed on the stress set; fail if above budget (search < 150 ms, list < 300 ms, dashboard < 300 ms on reference device).
- [ ] Run scenario in CI on web (headless Chrome) if feasible; Android on demand.
- [ ] `docs/TESTING.md`: how to run everything, reference devices.

## Acceptance
- [ ] E2E green on Android + Chrome
- [ ] Perf budgets met on a low-end Android device (document model) — or issues filed to owners with measurements
