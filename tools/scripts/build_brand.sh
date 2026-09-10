#!/usr/bin/env bash
# Builds one brand's web app (and optionally its Android APK).
#
#   tools/scripts/build_brand.sh <brandId> [dev|prod] [options]
#
# Steps: validate brand.json -> register the brand's assets in pubspec.yaml ->
# l10n -> codegen -> flutter build web -> per-brand PWA manifest, icons and
# index.html -> copy to dist/<brandId>.
#
# See TECHNICAL_STRUCTURE §13 and docs/BRAND_ONBOARDING.md.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

BRAND=""
ENV_NAME="dev"
BUILD_APK=false
REGISTER_ASSETS=true
RUN_L10N=true
RUN_CODEGEN=true
BASE_HREF="/"
OUT_ROOT="dist"

usage() {
  cat <<'USAGE'
Usage: tools/scripts/build_brand.sh <brandId> [dev|prod] [options]

  --apk                  also build a release APK into dist/apk/<brandId>-<version>.apk
  --base-href <path>     web base href (default "/")
  --out <dir>            output root (default "dist")
  --no-register-assets   fail instead of adding the brand to pubspec.yaml assets
  --skip-l10n            skip merge_arb + gen-l10n
  --skip-codegen         skip build_runner (use when it just ran, e.g. in CI)
  -h, --help             this message

Examples:
  tools/scripts/build_brand.sh acme
  tools/scripts/build_brand.sh acme prod --apk
USAGE
}

die() { echo "ERROR  $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk) BUILD_APK=true ;;
    --base-href) BASE_HREF="${2:-}"; [[ -n "$BASE_HREF" ]] || die "--base-href needs a value"; shift ;;
    --out) OUT_ROOT="${2:-}"; [[ -n "$OUT_ROOT" ]] || die "--out needs a value"; shift ;;
    --no-register-assets) REGISTER_ASSETS=false ;;
    --skip-l10n) RUN_L10N=false ;;
    --skip-codegen) RUN_CODEGEN=false ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; die "unknown option $1" ;;
    *)
      if [[ -z "$BRAND" ]]; then BRAND="$1"
      else ENV_NAME="$1"; fi
      ;;
  esac
  shift
done

[[ -n "$BRAND" ]] || { usage >&2; exit 1; }
[[ "$ENV_NAME" == "dev" || "$ENV_NAME" == "prod" ]] || die "environment must be dev or prod (got \"$ENV_NAME\")"
[[ -f "assets/brands/$BRAND/brand.json" ]] || die "assets/brands/$BRAND/brand.json not found. Create the brand with Brand Studio first (docs/BRAND_ONBOARDING.md)."
command -v flutter >/dev/null || die "flutter is not on PATH"

# --- 1. validate --------------------------------------------------------------
step "Validating assets/brands/$BRAND/brand.json"
dart run tools/scripts/gen_pwa_manifest.dart "$BRAND" --validate-only

# --- 2. make sure Flutter bundles this brand's assets -------------------------
ASSET_ENTRY="    - assets/brands/$BRAND/"
PUBSPEC_CHANGED=false
if ! grep -qxF "$ASSET_ENTRY" pubspec.yaml; then
  if [[ "$REGISTER_ASSETS" != true ]]; then
    die "pubspec.yaml does not bundle this brand. Add under flutter: assets:
$ASSET_ENTRY"
  fi
  step "Registering the brand in pubspec.yaml assets"
  awk -v entry="$ASSET_ENTRY" '
    { lines[NR] = $0 }
    /^    - assets\/brands\// { last = NR }
    END {
      if (last == 0) { print "no assets/brands entry found in pubspec.yaml" > "/dev/stderr"; exit 1 }
      for (i = 1; i <= NR; i++) { print lines[i]; if (i == last) print entry }
    }
  ' pubspec.yaml > pubspec.yaml.tmp
  mv pubspec.yaml.tmp pubspec.yaml
  PUBSPEC_CHANGED=true
  echo "    added \"$ASSET_ENTRY\" - commit this change with the brand folder"
fi

if [[ "$PUBSPEC_CHANGED" == true || ! -f .dart_tool/package_config.json ]]; then
  step "flutter pub get"
  flutter pub get
fi

# --- 3. generated code --------------------------------------------------------
if [[ "$RUN_L10N" == true ]]; then
  step "Translations (merge_arb + gen-l10n)"
  dart run tools/scripts/merge_arb.dart
  flutter gen-l10n
fi

if [[ "$RUN_CODEGEN" == true ]]; then
  step "Codegen (build_runner)"
  dart run build_runner build --delete-conflicting-outputs
fi

# --- 4. web build -------------------------------------------------------------
step "flutter build web (BRAND_ID=$BRAND, ENV=$ENV_NAME)"
flutter build web \
  --release \
  --base-href "$BASE_HREF" \
  --dart-define=BRAND_ID="$BRAND" \
  --dart-define=ENV="$ENV_NAME"

step "Brand manifest, icons and index.html"
dart run tools/scripts/gen_pwa_manifest.dart "$BRAND" --out build/web

step "Copying to $OUT_ROOT/$BRAND"
rm -rf "${OUT_ROOT:?}/$BRAND"
mkdir -p "$OUT_ROOT"
cp -R build/web "$OUT_ROOT/$BRAND"

# --- 5. optional APK ----------------------------------------------------------
if [[ "$BUILD_APK" == true ]]; then
  VERSION="$(awk '/^version:/ { print $2; exit }' pubspec.yaml)"
  VERSION="${VERSION%%+*}"
  step "flutter build apk (BRAND_ID=$BRAND, ENV=$ENV_NAME)"
  flutter build apk \
    --release \
    --dart-define=BRAND_ID="$BRAND" \
    --dart-define=ENV="$ENV_NAME"
  mkdir -p "$OUT_ROOT/apk"
  cp build/app/outputs/flutter-apk/app-release.apk "$OUT_ROOT/apk/$BRAND-$VERSION.apk"
  echo "    $OUT_ROOT/apk/$BRAND-$VERSION.apk"
fi

echo
echo "Done. Web build: $OUT_ROOT/$BRAND"
echo "Preview locally: (cd $OUT_ROOT/$BRAND && python3 -m http.server 8080)"
echo "Deploy:          tools/scripts/deploy_brand.sh $BRAND preview --env $ENV_NAME"
