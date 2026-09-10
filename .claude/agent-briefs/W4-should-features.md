# W4 — *Should* features (post-MVP, local-first)

Nine agent briefs (D1–D9). Each section is self-contained: give an agent **this file + AGENT_PHASES.md** and tell it which ID it is.

## Wave rules (in addition to AGENT_PHASES §7)

- **Starts after G3** (MVP released). The pilot keeps running on the tagged MVP; W4 merges go to `main` and ship after the pilot review.
- **Sub-waves** so no two agents edit the same feature at once:
  - **W4a (parallel):** D1, D2, D3, D4, D5, D7, D8, D9
  - **W4b (after D4 merges):** D6 (edits the stock feature, like D4)
- **Ownership after MVP:** a D agent may edit an MVP feature only where its brief says *"edits: …"*. Those edits go in a separate commit so the lead can review them against the original owner's tests.
- **Schema changes:** add a migration file named `m9xx_<slug>.dart` (placeholder number). The lead renumbers migrations in merge order (`m002…`). Migrations must upgrade a real pilot backup without data loss. Tested in `test/migrations/`.
- **New dependencies** (`pdf`, `printing`, `barcode`, `excel`, a charts package, `flutter_launcher_icons`, `flutter_native_splash`): list them in your report; the lead adds them to `pubspec.yaml` **before** launching W4a.
- Every feature is gated by its `FeatureFlag`. When the flag is off it is hidden in the UI **and** blocked in the use case.

---

## D1 — Stock count mode

| | |
|---|---|
| **Flag / tier** | `stockCount` · all tiers |
| **Owns** | `lib/features/stock_count/**`; tables `stock_counts`, `stock_count_lines` (new migration) |
| **Edits** | none — posts results through `StockRepository.record(type: count)` |

**Tasks**
- [ ] Start a count for the whole store or a category; the expected quantity is snapshotted at start
- [ ] Scan-first counting: scan → enter the counted qty. A second scan of the same product adds to it. Uncounted items are listed.
- [ ] Review screen: differences by quantity and value, sorted by largest loss. Include/exclude per line.
- [ ] Complete → one `count` movement per changed product (delta = counted − current, accounting for movements recorded during the count), in one transaction
- [ ] Resume an interrupted count; only one open count per branch

**Acceptance:** counting 50 items takes under 10 min (baseline task from the pilot); movements recorded during a count are handled correctly (test); count history is viewable.

---

## D2 — Activity log & price history

| | |
|---|---|
| **Flag / tier** | `activityLog` · Aisle+ (price history: Could, Aisle+) |
| **Owns** | `lib/features/activity_log/**`; table `audit_log` + **SQLite triggers** on `products`, `categories`, `profiles`, `settings` (new migration) |
| **Edits** | product detail: adds a "Price history" section via `activity_log/public.dart` (small PR to products, reviewed by the lead) |

**Tasks**
- [ ] Triggers write `audit_log(entity, entity_id, action, changed_fields JSON, profile_id, at)` so no other feature's code changes. `profile_id` comes from a `session_context` single-row table that the session updates.
- [ ] Unified timeline (`/activity`) merging `audit_log`, `stock_movements` and `price_changes`. Filter by person, type, date and product.
- [ ] Price history per product: chart plus table of old → new price and cost, and who changed it
- [ ] Export the log to CSV

**Acceptance:** every edit in the E2E scenario appears with the correct person; triggers add < 5 ms per write (perf test); hidden on the Shelf tier.

---

## D3 — Reports (basic + advanced)

| | |
|---|---|
| **Flag / tier** | basic: all tiers · `advancedReports`: Aisle+ |
| **Owns** | `lib/features/reports/**` (read-only SQL; no new tables) |

**Tasks**
- [ ] Basic: stock value by category (cost and retail); movements by reason for a date range; dead stock (no movement in N days, default 60)
- [ ] Advanced: stock turnover per category; shrinkage value (damaged + expired + negative adjustments); top stock-outs (count and days out of stock); impact of price changes (before/after margin)
- [ ] Date-range picker, CSV export per report, charts with theme tokens (readable in light and dark, RTL axis order)

**Acceptance:** report totals match hand-computed fixtures; 100k movements → every report loads in under 1 s on a mid device.

---

## D4 — Multi-branch & transfers

| | |
|---|---|
| **Flag / tier** | `multiBranch` · Aisle+ |
| **Owns** | `lib/features/branches/**` |
| **Edits** | `core/session/session_impl.dart` (current branch switcher); stock feature: transfer flow and a per-branch filter; dashboard: a branch selector with an "All branches" option |

**Tasks**
- [ ] Branch management: add, rename, archive. The default branch already exists from the MVP, so no data migration is needed.
- [ ] Branch switcher in the app bar; staff profiles can be restricted to one branch (new column `profiles.branch_id` → migration)
- [ ] Transfer: pick products and quantities → `transfer_out` at the source + `transfer_in` at the destination in one transaction, linked by `transfer_id`
- [ ] Reorder points per branch (move to `stock_levels.reorder_point_milli`; migration copies the product-level value)
- [ ] Dashboard and alerts filter by branch

**Acceptance:** stock is conserved across a transfer (property test); restoring an MVP backup still works; hidden on the Shelf tier.

---

## D5 — Suppliers, reorder list & purchase orders

| | |
|---|---|
| **Flag / tier** | `suppliers` · Aisle+ |
| **Owns** | `lib/features/suppliers/**`, `lib/features/purchasing/**`; tables `suppliers`, `product_suppliers`, `purchase_orders`, `purchase_order_lines`; column `products.reorder_qty_milli` (migration) |
| **Edits** | none — receiving against a PO calls `StockRepository.record(receive)` |

**Tasks**
- [ ] Suppliers: name, phone, WhatsApp, lead time in days; link products to suppliers with a supplier SKU and last cost
- [ ] Reorder list: low and out items grouped by supplier, with suggested qty = `reorder_qty` or `(2 × reorder_point − qty)`. Editable.
- [ ] Purchase order: draft → sent → partially received → received. Share as PDF or WhatsApp-ready text through the share sheet.
- [ ] Receive against a PO: pre-filled lines; differences are recorded

**Acceptance:** alert → reorder list → PO → receive closes the alert (E2E); PO PDF renders correctly in Arabic RTL.

---

## D6 — Expiry dates (batches) · *W4b*

| | |
|---|---|
| **Flag / tier** | `expiryDates` · Aisle+ |
| **Owns** | `lib/features/expiry/**`; table `stock_batches(product_id, branch_id, expiry_date, qty_milli)`; column `products.tracks_expiry` (migration) |
| **Edits** | stock receive flow (asks for the expiry date on tracked products); sales and damage deduct from the earliest-expiring batch first (FEFO) |

**Tasks**
- [ ] Toggle expiry tracking per product; receive asks for an expiry date per line
- [ ] Expiring-soon list (default 30 days) and an `expiring` alert level with a local notification
- [ ] "Expired" movement picks a batch; the batch qty always sums to `stock_levels` (invariant test)

**Acceptance:** FEFO deduction is correct across 3 batches; the expiring-soon alert fires once; no effect when the flag is off.

---

## D7 — Custom roles

| | |
|---|---|
| **Flag / tier** | `customRoles` · Aisle+ |
| **Owns** | `lib/features/roles/**`; table `roles(id, name, permissions JSON, is_builtin)`; column `profiles.role_id` (migration maps owner/staff to built-in roles) |
| **Edits** | `core/auth/permission.dart` (lead-approved: `Role` enum → `RoleDefinition`); `session_impl.dart` `can()` |

**Tasks**
- [ ] Role editor: name plus permission checkboxes grouped by area; built-in Owner (locked) and Staff (editable copy)
- [ ] Example template "Branch manager" (all stock + catalogue permissions, no price or settings permissions)
- [ ] At least one active profile must always hold owner permissions (guard)

**Acceptance:** every use case still enforces permissions (the existing permission tests pass against custom roles); a migrated MVP backup behaves identically.

---

## D8 — XLSX import & shelf label printing

| | |
|---|---|
| **Flag / tier** | XLSX: all tiers · `labelPrinting`: Aisle+ |
| **Owns** | `lib/features/labels/**`; **edits** `lib/features/import_export/**` (adds an XLSX parser next to CSV) |

**Tasks**
- [ ] XLSX import: first sheet or pick a sheet, same template and preview as CSV
- [ ] Label designer presets (A4 sheets such as 3×8 and 4×10, plus 58 mm thermal): name, price (large), barcode (EAN-13/Code128), optional old price. Brand logo optional.
- [ ] Print from: a product selection, a category, or **"products changed in price batch X"** (from `price_changes.batch_id`)
- [ ] Output is a PDF → system print or share

**Acceptance:** an Arabic product name renders correctly in RTL on the label; the barcodes scan with A5's scanner; a batch of 200 labels generates in under 5 s.

---

## D9 — Native brand apps & custom domain

| | |
|---|---|
| **Flag / tier** | Aisle+ (delivery feature, not in-app) |
| **Owns** | `android/app/build.gradle` flavors section, `ios/` schemes/xcconfigs, `tools/scripts/gen_flavors.dart`, `flutter_launcher_icons*.yaml`, `flutter_native_splash*.yaml`, `docs/NATIVE_APPS.md`, `docs/CUSTOM_DOMAIN.md` |

**Tasks**
- [ ] `gen_flavors.dart` generates an Android productFlavor and an iOS scheme per brand from `assets/brands/*/brand.json` (applicationId, display name, icon, splash)
- [ ] Build scripts accept `--flavor <brand>`; CI builds an AAB per brand on tag
- [ ] Docs: the brand's own Google Play ($25 once) and Apple Developer ($99/yr) accounts, signing keys kept per brand, store listing checklist in AR/EN
- [ ] Custom domain: script plus doc for Firebase Hosting custom domain per brand site (DNS records, SSL wait)

**Acceptance:** two brands installed side by side on one Android phone with separate names, icons and data; a custom domain serves a brand site over HTTPS.
