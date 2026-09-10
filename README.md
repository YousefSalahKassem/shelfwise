# ShelfWise

White-label product, price and stock manager for stores — Flutter (Android, iOS, Web, Windows, macOS), Clean Architecture, Riverpod, sqflite (local-first), Firebase Hosting for web.

- Business & features plan: https://claude.ai/code/artifact/81eac84a-52d7-4261-a5bd-330b71db7270
- Build plan: [.claude/PLAN.md](.claude/PLAN.md) · Technical design: [.claude/TECHNICAL_STRUCTURE.md](.claude/TECHNICAL_STRUCTURE.md)
- Parallel agent delivery: [.claude/AGENT_PHASES.md](.claude/AGENT_PHASES.md) · briefs in [.claude/agent-briefs/](.claude/agent-briefs/) · reports in [.claude/agent-reports/](.claude/agent-reports/)

## Getting started

```bash
flutter pub get
dart run tools/scripts/merge_arb.dart && flutter gen-l10n   # after editing any *.arb fragment
dart run build_runner build                                 # freezed + riverpod codegen
flutter analyze && flutter test

# Run a brand (folder name under assets/brands/)
flutter run -d chrome --web-port 8080 --dart-define=BRAND_ID=shelfwise
flutter run --dart-define=BRAND_ID=demo-green
```

Web uses `sqflite_common_ffi_web`: `web/sqlite3.wasm` and `web/sqflite_sw.js` are committed (regenerate with `dart run sqflite_common_ffi_web:setup`). Always use a fixed `--web-port` — the browser database is tied to the origin.

## Project layout (short)

```
lib/
  main.dart · bootstrap.dart · app.dart · shell/app_shell.dart
  core/        brand · database · router · theme · l10n · session · settings · platform · analytics · utils · widgets
  features/    <feature>/{domain,data,presentation,l10n} + public.dart
assets/brands/<brandId>/brand.json + logos · assets/fonts/
tools/scripts/merge_arb.dart · tools/dev_runner.sh
```

Rules for contributors and agents: see [.claude/AGENT_PHASES.md §7](.claude/AGENT_PHASES.md).
