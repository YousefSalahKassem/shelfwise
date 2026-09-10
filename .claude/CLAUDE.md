# ShelfWise — project memory for Claude Code

White-label product, price and stock manager for stores. Flutter (Android, iOS, Web, Windows, macOS) · Clean Architecture · Riverpod 3 (codegen) · sqflite local-first · Firebase Hosting (one site per brand).

## Read before working
- `.claude/PLAN.md` — what gets built and when (phases, open decisions, release checklist)
- `.claude/TECHNICAL_STRUCTURE.md` — architecture, schema, white-label, theming, l10n
- `.claude/AGENT_PHASES.md` — parallel delivery: waves, **ownership map (§5)**, **frozen contracts (§6)**, **agent rules (§7)**
- `.claude/agent-briefs/<wave>-<id>-*.md` — your task if you were launched as an agent
- `.claude/agent-reports/` — handoff reports (write yours here when done; template in AGENT_PHASES §9)
- Business plan: https://claude.ai/code/artifact/81eac84a-52d7-4261-a5bd-330b71db7270

## Commands
```bash
flutter pub get
dart run tools/scripts/merge_arb.dart && flutter gen-l10n   # after editing any *.arb fragment
dart run build_runner build                                 # freezed + riverpod codegen
flutter analyze && flutter test                             # must be green before handoff
flutter run -d chrome --web-port 8080 --dart-define=BRAND_ID=shelfwise   # or demo-green
```

## Non-negotiables (full list: AGENT_PHASES §7)
- Write only inside the paths and DB tables you own; read anything.
- Don't edit frozen contracts, `pubspec.yaml`, `bootstrap.dart`, or another feature's files — raise a change request in your report.
- `domain/` is pure Dart (no Flutter, sqflite, Riverpod). SQL only in `data/datasources/`. UI calls use cases.
- From another feature import only its `domain/` or `public.dart`.
- Money = `Money` (integer minor units), quantities = `Quantity` (thousandths). Never doubles.
- Every string in your feature's ARB fragment (en + ar, prefixed). Use `EdgeInsetsDirectional` / start/end for RTL.
- Every write use case checks `Permission` + `FeatureFlag`, runs in one transaction, calls `dbChanges.notify`, logs its `AppEvent`.
- White-label is configuration only (`assets/brands/<id>/brand.json`) — never brand-specific code.
- Never build *Won't* items (POS/checkout, accounting/e-invoicing, storefront, payments, HR, warehouse, CRM).
