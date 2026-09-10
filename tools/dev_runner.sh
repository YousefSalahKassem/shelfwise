#!/bin/bash
# ShelfWise dev runner
# Runs a fixed whitelist of Flutter tasks when a task list appears in .agent/request,
# and writes all output to .agent/output.log. Lets Claude build/verify the project
# from a sandbox that can't reach pub.dev. Stop anytime with Ctrl+C.
cd "$(dirname "$0")/.." || exit 1
mkdir -p .agent
echo "ShelfWise dev runner watching $(pwd)/.agent/request  (Ctrl+C to stop)"
while true; do
  if [ -f .agent/request ]; then
    tasks=$(cat .agent/request); rm -f .agent/request
    id=$(date +%Y%m%d-%H%M%S)
    echo "[$id] running: $tasks"
    {
      echo "=== run $id: $tasks"
      for t in $tasks; do
        echo "--- task: $t"
        case "$t" in
          doctor)   flutter --version; flutter doctor ;;
          create)   flutter create --platforms=android,ios,web,windows,macos --org com.shelfwise --project-name shelfwise . ;;
          pubget)   flutter pub get ;;
          websetup) dart run sqflite_common_ffi_web:setup ;;
          l10n)     dart run tools/scripts/merge_arb.dart && flutter gen-l10n ;;
          codegen)  dart run build_runner build --delete-conflicting-outputs ;;
          analyze)  flutter analyze ;;
          test)     flutter test ;;
          buildweb) flutter build web --release --dart-define=BRAND_ID=shelfwise ;;
          buildweb2) flutter build web --release --dart-define=BRAND_ID=demo-green ;;
          outdated) flutter pub outdated ;;
          gitinit)  git init -q 2>/dev/null; git add -A && git commit -qm "W0: foundation & contracts" && echo committed ;;
          *)        echo "unknown task: $t" ;;
        esac
        echo "--- exit($t): $?"
      done
      echo "=== done $id"
    } > .agent/output.log 2>&1
    echo "[$id] finished (see .agent/output.log)"
  fi
  sleep 2
done
