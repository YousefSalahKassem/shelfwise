# A7 — Brand Studio, build & deploy

| | |
|---|---|
| **Wave** | 1 (parallel) · branch `agent/A7-devops` · merge early in W1 |
| **Depends on** | G0 only |
| **Owns (code)** | `tools/brand_studio/**`, `tools/scripts/build_brand.sh`, `deploy_brand.sh`, `gen_pwa_manifest.dart`, `firebase.json`, `.firebaserc`, `.github/workflows/**`, `web/index.html`, `web/manifest.json` |
| **Owns (tables)** | none |
| **Consumes** | `BrandConfig` + validation (core/brand), `buildTheme` for previews |
| **Read first** | TECHNICAL_STRUCTURE §7, §13; business plan §8 ("your logo in 10 minutes" demo) |
| **Business-plan features** | Brand setup (tool), Branded web + installable app, Reseller console (local substitute) |

## Goal
Anyone on the team can create a new brand and have its branded web app live in under an hour — and show a prospect their own logo in the app during a sales call.

## Tasks
- [ ] **Brand Studio** (separate Flutter web app in `tools/brand_studio`, path-depends on the main package for `core/brand` + `core/theme`): form for id, app name, tier, primary/secondary colours (picker + hex), logo light/dark upload, default locale, supported locales, currency, support contacts, legal. **Live preview** of dashboard + product list mock in light/dark × AR/EN. Contrast warning (< 4.5:1). Export `brand.json` + assets as a zip in the expected folder layout. Import an existing brand to edit.
- [ ] **Build script** `build_brand.sh <brandId> [env]`: validate brand → `gen_pwa_manifest.dart` (name, short_name, theme/background colour, icons from brand logo) → `flutter build web --release --dart-define=BRAND_ID=… --dart-define=ENV=…` → copy to `dist/<brandId>`; `--apk` flag builds Android APK named `<brandId>-<version>.apk`.
- [ ] **Deploy script** `deploy_brand.sh <brandId> [channel]`: creates Hosting site + target if missing, adds `firebase.json` entry (rewrites, wasm header, cache headers per TECHNICAL_STRUCTURE §13), deploys to channel or live.
- [ ] Deploy Brand Studio itself as site `brand-studio` (dev project only).
- [ ] **CI** (GitHub Actions): on PR → build_runner, merge_arb, gen-l10n, analyze, test, build web for `shelfwise` brand, deploy preview channel, comment URL. On tag → build & deploy all brands in `assets/brands/*` to prod + attach APKs.
- [ ] `docs/BRAND_ONBOARDING.md`: step-by-step for the team (collect assets → Brand Studio → build → deploy → share link/APK).

## Acceptance
- [ ] New brand from zero to live preview URL in < 1 hour by following the doc
- [ ] Installed PWA shows the brand's name/icon/colours on Android home screen
- [ ] CI green on a sample PR and posts the preview link
