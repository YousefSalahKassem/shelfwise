# W5 — Sync & connected features

Resolves **OD-1** (PLAN §3): moves ShelfWise from "one device per store" to "any device, anywhere", keeping sqflite as the on-device source of truth.

## Wave rules

- **E0 runs alone first.** E1–E5 start in parallel only after E0 merges and gate G5 passes.
- Backend = the **same Firebase project** (Firestore, Auth, FCM). Free Spark plan covers E0, E1, E3, E4, E5. **E2 needs server code → Blaze plan 💳** (billing account; free quota applies).
- Features don't write to Firestore directly. They keep writing to sqflite through their repositories; **the sync engine moves rows**. Feature code only changes where a brief says *"edits"*.
- Firestore security rules live in `firebase/firestore.rules`, owned by E0. Other agents propose rule changes in their report and the lead merges them. Every rule change ships with emulator tests.

---

## E0 — Sync engine (serial)

| | |
|---|---|
| **Owns** | `lib/core/sync/**`, `lib/core/auth_remote/**`, `firebase/firestore.rules`, `firebase/firestore.indexes.json`, `test/sync/**`, emulator config |
| **Edits** | `bootstrap.dart` (start the sync service; lead-approved); migration adding `sync_outbox` and `sync_state` tables |
| **New deps** | `firebase_core`, `firebase_auth`, `cloud_firestore` (added by the lead) |

**Design (write `docs/SYNC_DESIGN.md` first; get it reviewed before coding)**
- Firestore layout: `brands/{brandId}/stores/{storeId}/{table}/{rowId}` plus `brands/{brandId}/stores/{storeId}/members/{uid}`
- **Outbox:** table-level triggers (like D2) enqueue `(table, row_id, op, updated_at)` into `sync_outbox` → push in batches → mark done. No feature code changes.
- **Pull:** per table, `updated_at > last_pulled_at` (plus soft-deleted rows) → upsert locally in one transaction → `dbChanges`
- **Conflicts:** last-write-wins per row by `updated_at` (server timestamp tiebreak). `stock_movements` and `price_changes` are append-only, so they never conflict. `stock_levels` is **recomputed from the ledger** after a pull, never synced as truth.
- **Auth:** Firebase Auth with email/password or email link (check current pricing and limits for phone/SMS before using it). A device signs in once; local PIN profiles remain for fast switching.
- **Rules:** access only if `members/{uid}` exists for that store; brand-admin access through `brands/{brandId}/admins/{uid}`. No custom claims (those need server code).
- **First sync:** upload an existing local store (from the MVP) with a progress bar; resumable.

**Acceptance (G5):** two devices edit offline, then converge after reconnect (scripted test on emulators); the ledger stays consistent; emulator rule tests prove there is no cross-store or cross-brand access; restoring an MVP backup and then syncing works.

---

## E1 — Multi-device profiles & staff invites

| | |
|---|---|
| **Owns** | `lib/features/invites/**` |
| **Edits** | profiles feature (link profile ↔ auth user, device list) |

- [ ] Owner creates an invite (6-character code + link, expires in 48 h) → staff installs the brand app, enters the code, and signs in → becomes a member linked to their profile
- [ ] Device list per profile; remove a device (revokes membership)
- [ ] Owner can open the store from home and see live stock (business plan persona success: *"check stock in both branches from his phone"*)

**Acceptance:** a staff member on their own phone records a delivery and the owner sees it within 10 s online; a revoked device can't pull data.

---

## E2 — Push & email alerts 💳

| | |
|---|---|
| **Owns** | `firebase/functions/**` (TypeScript), `lib/features/alerts/remote/**` |
| **Edits** | alerts feature (register the FCM token, notification preferences) |

- [ ] Cloud Function on `stock_alerts` create → FCM to the owner's devices (collapse per product) with an optional daily email digest
- [ ] Branded sender: brand name and from-address per brand (custom domain from D9); templates in AR/EN
- [ ] Preferences: push on/off, digest time, quiet hours

**Acceptance:** an alert raised on the staff device → push on the owner's phone in under 30 s; no duplicates; the email renders in RTL.

---

## E3 — Reseller console

| | |
|---|---|
| **Owns** | `tools/reseller_console/**` (Flutter web, deployed per brand as `console-<brand>`) |

- [ ] Brand admin sign-in → list of stores with last activity, product count, active staff, activation checklist status (pilot metric)
- [ ] Create a store and invite its owner; suspend or reactivate a store (the app shows a read-only banner when suspended)
- [ ] Monthly active-store count for billing (business plan: per-store fee), exportable as CSV

**Acceptance:** a brand admin sees only their own brand's stores (rule tests); suspension takes effect on the next sync.

---

## E4 — HQ master catalogue (Chain tier)

| | |
|---|---|
| **Flag / tier** | `hqMasterCatalogue` · Chain |
| **Owns** | `lib/features/hq_catalogue/**`; Firestore `brands/{brandId}/catalogue/**` |
| **Edits** | products and pricing (a "managed by HQ" lock on fields) |

- [ ] HQ edits master products and prices → pushed to all stores in the chain
- [ ] Per-field policy: price locked, suggested, or local; branches can't edit locked fields
- [ ] Rollout: apply now or schedule (e.g. new prices from Sunday)

**Acceptance:** a price change at HQ appears in 20 stores after sync; a locked field can't be edited locally (use case + UI).

---

## E5 — Cloud analytics

| | |
|---|---|
| **Owns** | `lib/core/analytics/impl/firebase_analytics_impl.dart`, `docs/METRICS.md` |
| **New deps** | `firebase_analytics` |

- [ ] Mirror every `AppEvent` to Firebase Analytics (keep the local log too), with user properties brand, tier, store and role
- [ ] `docs/METRICS.md`: how each business-plan §9 metric is computed (activation, weekly active stores, churn, time saved inputs, revenue per brand from E3 counts)
- [ ] Privacy note in the settings "About" screen

**Acceptance:** the activation funnel for a test brand is visible in the Firebase console.
