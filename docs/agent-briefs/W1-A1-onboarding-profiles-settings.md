# A1 — Onboarding, profiles & settings

| | |
|---|---|
| **Wave** | 1 (parallel) · branch `agent/A1-onboarding` |
| **Depends on** | G0 only |
| **Owns (code)** | `lib/features/onboarding/**`, `lib/features/profiles/**`, `lib/features/settings/**`, `lib/core/session/session_impl.dart`, `lib/core/settings/preferences_impl.dart` |
| **Owns (tables)** | `stores`, `branches`, `profiles`, `settings` |
| **Consumes** | `SessionReader`, `Permission`, `FeatureFlags` (`maxStaffProfiles`), `AnalyticsService` |
| **Read first** | TECHNICAL_STRUCTURE §7, §8, §9, §10, §15 (security) |
| **Business-plan features** | Sign-in & staff invites (local profiles), Owner & staff roles, AR/EN setting, theme setting |

## Goal
First-run setup, profile switching with PIN on a shared store device, role enforcement, and the settings screen (theme, language, digits).

## Tasks
- [ ] **Onboarding** (`/onboarding`): store name → currency (EGP/SAR, default from brand) → language → owner name + 4–6 digit PIN (confirm). Creates store, default branch and owner in one transaction. Logs `store_created`.
- [ ] **Session implementation**: replace the W0 stub `lib/core/session/session_impl.dart` (bootstrap already uses it). Holds current profile, auto-locks after idle (default 5 min, setting), survives app restart as *locked*.
- [ ] **Lock screen** (`/lock`): grid of active profiles → `PinPad` → verify. 5 wrong attempts → 30 s cooldown. Logs `session_started`, `profile_switched`.
- [ ] **Profiles** (`/settings/profiles`, owner only): list, add staff (name, PIN, language), edit, reset PIN, deactivate (never delete — movements reference them). Enforce `maxStaffProfiles` (Shelf = 3) → `FeatureLockedFailure` with upgrade hint.
- [ ] **PIN security**: PBKDF2-HMAC-SHA256 with per-profile random salt via `crypto`; constant-time compare.
- [ ] **Guards**: implement `can(Permission)` from `defaultRolePermissions`; router redirects deny both navigation and direct URL entry on web.
- [ ] **Settings** (`/settings`): theme mode (system/light/dark), language (brand's supported locales), digits (Arabic-Indic/Latin), auto-lock minutes, store name & currency (owner), about brand (support phone/WhatsApp/email from `brand.json`), links to backup and import routes (constants only).
- [ ] **Preferences**: replace the W0 in-memory stub `lib/core/settings/preferences_impl.dart` with persistence in the `settings` table (keep `PreferencesController` name, state type and methods).
- [ ] Locale priority is already implemented in `effectiveLocaleProvider` (device preference → profile → store → brand default).

## Acceptance
- [ ] Fresh install → onboarding → dashboard placeholder; reinstall-free restart goes to `/lock`
- [ ] Staff cannot open `/prices/bulk` or `/settings/profiles` by tapping **or** by URL on web
- [ ] 4th staff profile on a `shelf` brand is blocked with a translated message; allowed on `aisle`
- [ ] Theme/language/digits switch instantly and persist; AR layout mirrors
- [ ] Unit tests: PIN hashing/verify, lockout, permission matrix; repository tests for all four tables; widget tests for onboarding and lock (LTR + RTL)
