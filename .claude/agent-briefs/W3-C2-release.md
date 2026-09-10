# C2 — Release & pilot builds (lead)

| | |
|---|---|
| **Wave** | 3 · after C1 |
| **Depends on** | G2 + C1 |
| **Owns** | Release branch/tag, `CHANGELOG.md`, pilot brand folders `assets/brands/<pilot>/**` |
| **Read first** | PLAN §5 P7, §8; business plan §7 (pilot) |

## Tasks
- [ ] Create the 3 pilot brands with Brand Studio; review assets and contrast
- [ ] Version bump, `CHANGELOG.md`, tag `v0.1.0-pilot`
- [ ] Build & deploy each pilot brand to Firebase **prod**; build signed Android APKs
- [ ] Run PLAN §8 release checklist per brand; archive previous APKs for rollback
- [ ] Prepare pilot kit: quick guide (AR/EN), 15-minute staff walkthrough script, baseline-timing sheet, weekly check-in checklist (export usage data + backup)

## Acceptance (gate G3 — MVP)
- [ ] All 3 pilot brands live with correct identity on web and APK
- [ ] E2E + goldens green on the tagged commit
- [ ] Pilot kit ready for onboarding week (PLAN Weeks 9–10)
