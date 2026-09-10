# A5 — Platform services

| | |
|---|---|
| **Wave** | 1 (parallel) · branch `agent/A5-platform` · **merge first in W1** |
| **Depends on** | G0 only |
| **Owns (code)** | `lib/core/platform/impl/**` (interfaces stay frozen in `lib/core/platform/`) |
| **Owns (tables)** | none |
| **Read first** | TECHNICAL_STRUCTURE §11, §1 (platform matrix) |
| **Business-plan features** | Barcode scanning, local notifications for low-stock alerts, file pick/save for import/export/backup |

## Goal
Real implementations of `ScannerService`, `NotificationService` and `FileService` on every target platform, swapped in through provider overrides.

## Tasks
- [ ] **Scanner**: `mobile_scanner` full-screen scan page (torch, camera switch, beep/vibrate, EAN-13/EAN-8/UPC/Code128/QR) on Android, iOS, macOS, Web; returns first stable code. Windows/Linux (and when no camera): `KeyboardWedgeScanner` dialog — focused field, accepts rapid input ending with Enter. Camera-permission denied → translated explanation + manual entry.
- [ ] **Notifications**: `flutter_local_notifications` init per platform (Android channel "Low stock", iOS/macOS permission, Windows/Linux, Web Notifications API). `requestPermission()` only after a user tap (web requirement). Tapping a notification deep-links to `/alerts`. Throttle: max one per product per level per hour.
- [ ] **Files**: pick (`file_picker`, with bytes on web), save (mobile: share sheet via `share_plus`; desktop: save dialog; web: browser download).
- [ ] Replace the W0 stub `lib/core/platform/impl/platform_providers.dart` so the providers return the real implementations (bootstrap already uses it; keep fakes for tests).
- [ ] Translations in `lib/core/platform/impl/l10n/platform_{en,ar}.arb` (prefix `platform_`).

## Acceptance
- [ ] Scan works on a physical Android phone and in Chrome (desktop webcam + phone camera over HTTPS preview channel)
- [ ] USB scanner input works on Windows and Chrome
- [ ] Notification shows and deep-links on Android, Chrome, Windows
- [ ] Save/pick verified on Android, Chrome, Windows, macOS
- [ ] Each impl has a small manual test page under `/dev/platform` (debug builds only)
