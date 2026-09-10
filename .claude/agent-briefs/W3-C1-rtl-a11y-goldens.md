# C1 — RTL, accessibility & golden tests

| | |
|---|---|
| **Wave** | 3 · branch `agent/C1-quality` |
| **Depends on** | G2 |
| **Owns (code)** | `test/goldens/**`; fixes elsewhere **only as small, separate PRs** reviewed by the file's owner or the lead |
| **Read first** | TECHNICAL_STRUCTURE §8, §9, §14 |
| **Business-plan features** | Arabic & English (RTL) quality; "works on cheap phones"; staff persona usability |

## Tasks
- [ ] Golden tests: dashboard, product list, product form, receive delivery, bulk price preview, alerts, lock screen × brands {shelfwise, demo-green} × {light, dark} × {en-LTR, ar-RTL}
- [ ] RTL audit: grep for `EdgeInsets.only(left|right`, `Alignment.centerLeft/Right`, `TextAlign.left/right`, non-mirrored directional icons; fix via owner PRs
- [ ] Accessibility: semantics labels on icon buttons, 48 dp targets, text scale 1.3× without overflow, contrast AA in both themes, focus order on web/desktop
- [ ] Translation review: every `ar` string reviewed by a native speaker; consistent terms glossary (`docs/GLOSSARY.md`: SKU, reorder point, stock value…)
- [ ] Empty/error/loading states present on every screen

## Acceptance
- [ ] Goldens committed and green in CI
- [ ] Zero overflow errors at 1.3× in both directions
- [ ] Glossary approved; no English leaking into the AR UI
