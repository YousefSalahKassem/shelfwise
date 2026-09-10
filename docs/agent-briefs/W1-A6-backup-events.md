# A6 — Backup, restore & pilot events

| | |
|---|---|
| **Wave** | 1 (parallel) · branch `agent/A6-backup` |
| **Depends on** | G0 only |
| **Owns (code)** | `lib/features/backup/**`, `lib/core/analytics/impl/**` |
| **Owns (tables)** | `app_events`; **restore** may write all tables (only inside `RestoreBackup`) |
| **Consumes** | `FileService`, schema constants, migration runner, `SessionReader` |
| **Read first** | TECHNICAL_STRUCTURE §6 (web rules), §11, §12; PLAN §7 |
| **Business-plan features** | Data safety for local-first; pilot success measures (activation, retention, time saved inputs) |

## Goal
No store loses its data, and the pilot team can collect usage metrics from every store at weekly check-ins.

## Tasks
- [ ] **`AnalyticsService` impl** (replace W0 stub `analytics_impl.dart`): writes `app_events` (name, JSON props, profile, timestamp); batching; never throws into the UI.
- [ ] **Backup** (`/settings/backup`, owner): JSON file `{schemaVersion, brandId, storeId, createdAt, tables:{…}}` with BLOBs base64; filename `<brand>-<store>-YYYYMMDD-HHmm.shelfwise.json`; logs `backup_created`; stores `last_backup_at`.
- [ ] **Restore**: pick file → validate brand/schema → show summary (counts per table, date) → confirm (double confirm: overwrites everything) → migrate if older schema → replace all tables in one transaction → `dbChanges` all → restart session to `/lock`.
- [ ] **Backup reminder**: `BackupReminderBanner` + `backupReminderProvider` in `backup/public.dart` (replace W0 stub); B1 places it on the dashboard when last backup > 7 days or never.
- [ ] **Web persistence**: request `navigator.storage.persist()` on first run (via `dart:js_interop`), store result in settings; show a warning if denied.
- [ ] **Pilot export** (`/settings/backup` → "Export usage data"): CSV of `app_events` + computed activation summary (products count, reorder points set, movements, active days) per store.

## Acceptance
- [ ] Backup on Android → restore on Chrome gives identical row counts and a working app
- [ ] Restore of a file from another brand is rejected with a clear message
- [ ] Corrupt/partial file → nothing changes
- [ ] Events logged by A1–A4 appear in the export after merge (verify at G1)
