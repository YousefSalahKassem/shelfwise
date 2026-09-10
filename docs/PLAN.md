# ShelfWise — Project Plan

> Build plan for the ShelfWise MVP, derived from the [business & features plan](https://claude.ai/code/artifact/81eac84a-52d7-4261-a5bd-330b71db7270) (§6 Features, §7 MVP & pilot, §9 Success measures).
> Technical design: [`TECHNICAL_STRUCTURE.md`](./TECHNICAL_STRUCTURE.md).
> Parallel execution by agents (waves W0–W6, one brief per agent): [`AGENT_PHASES.md`](./AGENT_PHASES.md).
> Status: **pre-project**. Nothing is built yet.

---

## 1. Goal

Ship a white-label MVP that three pilot brands (1 reseller, 1 distributor/accounting firm, 1 small chain) can put in front of **15–25 stores**. Each brand gets its own name, logo and colours, and stores run it on Android and web.

The MVP must prove three things (business plan §7):

1. A brand can go live with its own look **in under a day**.
2. A store can load its catalogue and start tracking stock **in its first week**.
3. Low-stock alerts **change how owners reorder**.

**Timeline:** 8 weeks of build (Weeks 1–8), then 2 weeks of pilot onboarding (Weeks 9–10), matching the business-plan pilot schedule.

---

## 2. Decisions already made

| Area | Decision |
|---|---|
| Frontend | Flutter, one codebase: Android, iOS, Web, Windows, macOS |
| Architecture | Clean Architecture, feature-first (`presentation → domain ← data`) |
| State management | Riverpod 3 with code generation (also used for DI) |
| Database | sqflite (relational SQLite, local): native on mobile/macOS, `sqflite_common_ffi` on Windows/Linux, `sqflite_common_ffi_web` on web |
| Theming | Brand palette × light/dark/system, from `brand.json` |
| Localization | Arabic (RTL) + English via ARB / gen-l10n; more languages by adding ARB files |
| Web deploy | Firebase Hosting (free Spark plan), one site per brand |
| White-label | Configuration only (`brand.json` + assets), one build per brand via `--dart-define=BRAND_ID` |
| Cost | Free tools only. iOS App Store and Google Play listings are out of the pilot because they aren't free. |

---

## 3. Open decisions (need an answer before the stated deadline)

| ID | Question | Why it matters | Options | Recommendation | Decide by |
|---|---|---|---|---|---|
| **OD-1** | Is **local-only** data enough for the pilot? | With a local DB, data stays on one device. Owners can't check stock from home, staff can't use their own phones, and the reseller can't see its stores. Business-plan metrics such as *staff activation* and the *owner remote view* depend on this. | **A.** Pilot with one shared device per store (tablet/phone at the counter, owner + staff profiles). **B.** Add a *Sync* phase (Firestore on the same free Firebase project, ~2–3 weeks), using the sync-ready schema. | Start with **A** (the schema is already sync-ready). Re-decide after pilot-brand interviews in Week 2. If ≥2 brands say remote view is a must, schedule **B** as Phase 8 before the pilot. | End of Week 2 |
| OD-2 | Which platforms are in the pilot build? | Each platform needs its own testing effort | Android + Web (required); Windows (if a pilot store has a counter PC); iOS (needs paid account) | Android + Web. Add Windows only on request. | Week 1 |
| OD-3 | Default digits in the Arabic UI | Many shops prefer Latin digits even in Arabic | Arabic-Indic / Latin / per-brand default | Per-brand default, user can change | Week 3 |
| OD-4 | How to collect pilot metrics | Local-only means no server analytics | Local `app_events` table exported at weekly check-ins / Firebase Analytics (free) | Local events now. Add Firebase Analytics if OD-1 = B. | Week 6 |
| OD-5 | Commit generated code (`*.g.dart`, `*.freezed.dart`)? | CI speed vs. repo noise | Commit / regenerate in CI | Regenerate in CI | Week 1 |

---

## 4. Scope: business-plan features → build phases

### Must (MVP), all tiers

| Feature (business plan §6) | Phase | MVP implementation note (local-only) |
|---|---|---|
| Brand setup (theming) | P0, P1 | `brand.json` + Brand Studio tool |
| Branded web + installable app | P0, P7 | Firebase site per brand + PWA manifest; Android APK per brand |
| Multi-tenant data isolation | P1 | Per-device DB, per-brand web origin, `store_id` on every row |
| Sign-in & staff invites | P2 | Local profiles + PIN on a shared device (invites need sync, OD-1) |
| Owner & staff roles | P2 | Permission matrix in domain |
| Products | P3 | CRUD, SKU, barcode, unit, cost/price, photo (BLOB thumbnail) |
| Categories | P3 | Two levels |
| Price management | P4 | Single edit + bulk by category (% or fixed) + rounding + margin |
| Stock levels & movements | P5 | Ledger + cached levels, reasons |
| Low-stock alerts | P5 | Reorder points, alert list, **local** notifications (push/email need sync) |
| Home dashboard | P5 | Low/out counts, stock value (cost & retail), recent changes |
| Search & filters | P3 | Name, SKU, barcode; category and stock status |
| CSV/Excel import & export | P6 | CSV with preview and errors; full JSON backup/restore |
| Arabic & English (RTL) | P0 → all | Built in from day one, never retrofitted |
| Reseller console | P1 (Brand Studio) | Brand config editor + preview. Store management needs sync (OD-1). |

### Should, pulled into the MVP

| Feature | Phase | Note |
|---|---|---|
| Barcode scanning | P3 | Business plan §7 includes it in the MVP |

### Should, prepared for but not built

The schema and flags are ready so these need no restructuring later: stock count mode, activity log (`price_changes` + `stock_movements` already record who did what), basic reports, offline (already offline by design), multi-branch (the `branches` table exists), suppliers/reorder list, custom roles, expiry dates, HQ master catalogue, custom domain, own-brand store apps.

### Won't in v1 (from the business plan)

POS/checkout, accounting and e-invoicing, online storefront, payments, HR/payroll, warehouse/manufacturing, loyalty/CRM, per-client custom code.

---

## 5. Phases

Each phase ends with a **demoable build** deployed to the Firebase `dev` preview channel.

> **Execution with parallel agents:** these phases are *what* gets built. [`AGENT_PHASES.md`](./AGENT_PHASES.md) regroups them into waves that agents run in parallel: P0–P1 → W0 (+A7) · P2–P5 and backup → W1 (A1–A6) · dashboard, CSV and E2E → W2 · P7 → W3 · *Should* → W4 · P8 sync → W5 · *Could* → W6.

### P0 · Foundation (Week 1)

- [ ] Repo, `flutter create --platforms=android,ios,web,windows,macos --org <org> shelfwise`
- [ ] `analysis_options.yaml` (lints, Riverpod lint), `build.yaml`, `l10n.yaml`, folder skeleton per TECHNICAL_STRUCTURE §4
- [ ] Add packages and pin versions: riverpod (+generator), go_router, freezed, sqflite (+ffi, +ffi_web), intl, flutter_localizations, flutter_local_notifications, mobile_scanner, file_picker, csv, share_plus, path_provider, crypto, uuid, mocktail
- [ ] `dart run sqflite_common_ffi_web:setup` → commit `web/sqlite3.wasm`, `web/sqflite_sw.js`
- [ ] `core/`: `Result`/`Failure`, `db_factory` (io/web), `AppDatabase` shell, `BrandConfig` + loader + `FeatureFlags`, theme builder + `StockColors`, ARB files (en/ar), router shell with responsive `AppScaffold`
- [ ] Two sample brands (`shelfwise`, `demo-green`) to prove white-label from day one
- [ ] Firebase: create `shelfwise-dev` and `shelfwise-prod` projects, one site per sample brand, `firebase.json` targets, `deploy_brand.sh`
- [ ] **Platform smoke test:** open DB, write and read a row on Android, iOS simulator, Chrome, Windows, macOS

**Done when:** the empty app runs on every target platform, switches brand by `--dart-define`, toggles light/dark/system and AR/EN (RTL flips correctly), persists a test row, and is live on a Firebase preview URL per brand.

### P1 · Data core & Brand Studio (Week 2)

- [ ] Migration `m001_initial` with the full v1 schema (TECHNICAL_STRUCTURE §6), indexes, `PRAGMA foreign_keys`
- [ ] Base DAO helpers: timestamps, soft delete, UUIDs, change stream (`dbChangesProvider`)
- [ ] `Money` (minor units) and `Quantity` (thousandths) value objects + locale formatting
- [ ] Repository test harness on in-memory `sqflite_common_ffi`
- [ ] `tools/brand_studio`: edit name, logo, colours, tier, locales → live preview (light/dark, AR/EN) → export brand folder; contrast warning
- [ ] **Pilot-brand interviews** (owner and reseller needs) → answer **OD-1**

**Done when:** migrations are tested, and a new brand can be created in Brand Studio and deployed as a site in **under 1 hour** (target for the pilot: under a day).

### P2 · Onboarding & profiles (Week 2–3)

- [ ] First-run onboarding: store name, currency (EGP/SAR), language, owner profile + PIN → creates store and default branch
- [ ] Profiles: add, edit, deactivate staff (limit from `FeatureFlags.maxStaffProfiles`: Shelf = 3)
- [ ] Lock screen: pick profile + PIN, auto-lock on idle, switch profile
- [ ] Permission matrix + router guards (owner vs staff)
- [ ] Settings: theme mode, language, digits (OD-3)

**Done when:** a staff profile cannot reach price editing or settings through the UI *or* by typing the URL on web.

### P3 · Catalogue (Weeks 3–4)

- [ ] Categories: two-level CRUD, reorder, delete rules (only when empty, or move products)
- [ ] Products: create, edit, archive; validation (unique barcode/SKU per store, price ≥ 0); photo → compressed BLOB thumbnail
- [ ] Product list: search (name, `name_alt`, SKU, barcode), filter by category and stock status, paging for 5,000+ items
- [ ] Barcode: `ScannerService` → find product or prefill a new one; keyboard-wedge input for USB scanners on desktop/web
- [ ] Seed catalogues (mini-market, pharmacy) for demos and performance tests

**Done when:** 5,000 seeded products search in < 150 ms on a low-end Android device, and scan-to-find works on Android and Chrome.

### P4 · Pricing (Week 4–5)

- [ ] Single price/cost edit with margin % shown
- [ ] **Bulk update:** choose category (or selection) → +/− % or fixed amount → rounding rule (none / 0.05 / 0.25 / 0.50 / 1.00) → preview of old vs new → apply in one transaction
- [ ] Every change is written to `price_changes` with `batch_id` and profile
- [ ] Owner-only permission enforced in the use case

**Done when:** repricing a 200-product category takes **under 2 minutes** end to end (business plan §9 target).

### P5 · Stock, alerts & dashboard (Weeks 5–6)

- [ ] `RecordStockMovement` use case: receive, sale, damaged, expired, adjustment. It writes the ledger, updates the cached level and opens/resolves the alert in **one transaction**.
- [ ] Receive-delivery flow optimised for scanning (scan → qty → next), with a cost update option
- [ ] Reorder point per product (and bulk set by category)
- [ ] Alerts: low/out list, acknowledge, local notification when an alert is newly opened (respect OS permission; web asks only after a tap)
- [ ] Dashboard: low-stock count, out-of-stock count, stock value at cost and retail, last 10 changes, quick actions
- [ ] Product detail: stock history timeline

**Done when:** the integration scenario *add product → receive 10 → sell 8 (reorder point 3) → alert fires → dashboard updates* passes on Android and Chrome, and a 30-item delivery can be received in **under 5 minutes** (staff persona target).

### P6 · Import, export & backup (Week 7)

- [ ] Downloadable CSV template (AR/EN headers)
- [ ] Import: parse off the UI thread → preview with row errors → batch insert → summary; auto-create categories
- [ ] Export: products with stock and value; movements by date range
- [ ] Full JSON backup/restore with schema version; backup reminder; `navigator.storage.persist()` request on web
- [ ] Local `app_events` logging for pilot metrics (§7 below) + export

**Done when:** a real pilot-store Excel file (saved as CSV) of ~1,000 rows imports cleanly, and a backup restores on a *different* platform (e.g. Android → web).

### P7 · Hardening & pilot builds (Week 8)

- [ ] RTL and accessibility pass (text scale 1.3×, screen reader labels, contrast)
- [ ] Golden tests: key screens × 2 brands × light/dark × LTR/RTL
- [ ] Performance pass on a low-end Android device
- [ ] Error states and empty states on every screen, all translated
- [ ] Release builds: web per pilot brand → Firebase `prod`; Android APK per brand
- [ ] In-app "About": brand support contacts from `brand.json`
- [ ] Bug bash with 2–3 people outside the team

**Done when:** the release checklist (§8) passes for all 3 pilot brands.

### P8 · Sync (optional, only if OD-1 = B), +2–3 weeks

Firestore (free Spark tier) as the remote data source behind the existing repositories; push via FCM; multi-device profiles; basic reseller view of stores. This moves the pilot start back by the same amount.

### Pilot prep (Weeks 9–10, business plan §7)

- [ ] Create the 3 pilot brands in Brand Studio; deploy sites; build APKs
- [ ] Import each store's catalogue (the "we set it up for you" day)
- [ ] 15-minute staff walkthrough script (AR/EN); one-page quick guide
- [ ] Baseline timings per store: count 50 items, update 20 prices, receive a delivery
- [ ] Weekly check-in routine: export `app_events` + backup from each store

---

## 6. Timeline

| Week | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| P0 Foundation | ■ | | | | | | | | | |
| P1 Data core + Brand Studio | | ■ | | | | | | | | |
| P2 Onboarding & profiles | | ■ | ■ | | | | | | | |
| P3 Catalogue + scanning | | | ■ | ■ | | | | | | |
| P4 Pricing | | | | ■ | ■ | | | | | |
| P5 Stock, alerts, dashboard | | | | | ■ | ■ | | | | |
| P6 Import/export/backup | | | | | | | ■ | | | |
| P7 Hardening & builds | | | | | | | | ■ | | |
| Pilot onboarding | | | | | | | | | ■ | ■ |
| **Decisions** | OD-2, OD-5 | **OD-1** | OD-3 | | | OD-4 | | | | |

The live pilot runs Weeks 11–18, followed by measure & decide in Weeks 19–20 (business plan §7).

---

## 7. Measuring the pilot (business plan §9)

| Metric | Pilot target | Source in the app |
|---|---|---|
| Brand go-live | ≤ 14 days | Brand Studio export date → first `store_created` |
| Store activation (7 days: ≥50 products, ≥10 reorder points, ≥1 movement) | ≥ 60% | `product_created`, `reorder_point_set`, `stock_movement_recorded` |
| Staff activation (week 1) | ≥ 50% | `profile_switched` / `session_started` by staff role |
| Weekly active stores (≥3 active days/week at week 8) | ≥ 50% | `session_started` per day |
| Category price update | < 2 min | Timed task + `bulk_price_updated` duration prop |
| Stock-outs on top 20 items | −25% | `low_stock_alert_fired` level `out` vs first 2 weeks |
| Time saved | ≥ 2 h/week | Baseline vs week-6 timed tasks + weekly in-app question |

Without sync (OD-1 = A), events are collected by export at each weekly check-in.

---

## 8. Definition of done & release checklist

**Every feature**

- [ ] Domain use case + unit tests; repository tests against in-memory DB
- [ ] All strings in ARB (en + ar); no hard-coded brand name
- [ ] Works in light and dark, LTR and RTL, compact and expanded layouts
- [ ] Permission and tier checks in the use case (not only hidden in UI)
- [ ] Error, empty and loading states
- [ ] No `domain/` imports of Flutter/sqflite; no SQL outside `data/datasources`

**Every pilot release**

- [ ] `flutter analyze` clean, all tests green, goldens updated intentionally
- [ ] Integration scenario passes on Android + Chrome
- [ ] Migrations tested from every shipped schema version
- [ ] Backup → restore verified
- [ ] Each brand's site and APK shows the correct name, logo, colours, locale and support contacts
- [ ] Tagged release, changelog, previous APK kept for rollback

---

## 9. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Local-only data doesn't fit how owners work (want remote view) | Low retention, weak pilot | OD-1 decided in Week 2; sync-ready schema; P8 ready to schedule |
| `sqflite_common_ffi_web` is experimental (slow, bugs) | Web users hit errors or data loss | Web smoke tests every phase; backup reminders; Android as the primary pilot platform; performance budget checked in P3 |
| Browser storage cleared → data lost | Store loses catalogue | Persistent-storage request, backup reminder, restore across platforms |
| Data entry burden kills adoption (business plan risk) | Stores never activate | CSV import in P6, scan-first flows, "we set it up for you" day |
| White-label drift (a brand asks for custom code) | Codebase forks | Everything via `brand.json` + flags; custom requests go to the backlog as general features |
| RTL/Arabic bugs found late | Poor first impression in beachhead markets | Arabic from P0, RTL goldens, native Arabic speaker in the bug bash |
| Free-tier limits (Firebase Hosting) | Sites stop serving | Well within limits at pilot scale; monitor usage in the console; budget for paid plan before the first paying brand |

---

## 10. Before writing the first line of code

- [ ] Confirm OD-2 (pilot platforms) and OD-5 (generated code)
- [ ] Book pilot-brand interviews for Week 2 (answers OD-1)
- [ ] Collect brand assets for 2 sample brands (logo light/dark, colours)
- [ ] Get one real store catalogue (Excel) to use as import test data
- [ ] Get test devices: one low-end Android phone, Chrome/Edge/Safari, a USB barcode scanner (optional)
- [ ] Create both Firebase projects and the GitHub repo
