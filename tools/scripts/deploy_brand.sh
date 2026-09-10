#!/usr/bin/env bash
# Deploys one brand's web app to Firebase Hosting.
#
#   tools/scripts/deploy_brand.sh <brandId> [channel] [options]
#
# With a channel  -> a preview URL that expires (default 7 days).
# Without one     -> the live site.
#
# The script creates the Hosting site and the deploy target the first time it sees
# a brand, and adds the brand's entry to firebase.json. Needs `firebase login`.
# See TECHNICAL_STRUCTURE §13 and docs/BRAND_ONBOARDING.md.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

BRAND=""
CHANNEL=""
ENV_NAME="dev"
SITE=""
EXPIRES="7d"
DO_BUILD=false

usage() {
  cat <<'USAGE'
Usage: tools/scripts/deploy_brand.sh <brandId> [channel] [options]

  --env dev|prod     Firebase project alias from .firebaserc (default dev)
  --site <name>      Hosting site name (default <brandId>-shelfwise[-dev])
  --expires <dur>    preview channel lifetime (default 7d)
  --build            run build_brand.sh first
  -h, --help         this message

Examples:
  tools/scripts/deploy_brand.sh acme preview --build
  tools/scripts/deploy_brand.sh acme --env prod          # live
USAGE
}

die() { echo "ERROR  $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_NAME="${2:-}"; [[ -n "$ENV_NAME" ]] || die "--env needs a value"; shift ;;
    --site) SITE="${2:-}"; [[ -n "$SITE" ]] || die "--site needs a value"; shift ;;
    --expires) EXPIRES="${2:-}"; [[ -n "$EXPIRES" ]] || die "--expires needs a value"; shift ;;
    --build) DO_BUILD=true ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; die "unknown option $1" ;;
    *)
      if [[ -z "$BRAND" ]]; then BRAND="$1"
      else CHANNEL="$1"; fi
      ;;
  esac
  shift
done

[[ -n "$BRAND" ]] || { usage >&2; exit 1; }
[[ -f "assets/brands/$BRAND/brand.json" ]] || die "assets/brands/$BRAND/brand.json not found"
command -v firebase >/dev/null || die "firebase CLI not found - install it with: npm i -g firebase-tools"

PROJECT="$(dart run tools/scripts/hosting_config.dart project "$ENV_NAME")"

# --- 1. build if asked, or if there is nothing to deploy ----------------------
if [[ "$DO_BUILD" == true || ! -d "dist/$BRAND" ]]; then
  step "Building $BRAND ($ENV_NAME)"
  tools/scripts/build_brand.sh "$BRAND" "$ENV_NAME"
fi

# --- 2. firebase.json entry ---------------------------------------------------
step "firebase.json"
dart run tools/scripts/hosting_config.dart ensure "$BRAND"

# --- 3. hosting site + deploy target -----------------------------------------
if [[ -z "$SITE" ]]; then
  SITE="$(dart run tools/scripts/hosting_config.dart site "$BRAND" --project "$PROJECT")"
fi
if [[ -z "$SITE" ]]; then
  # Convention (TECHNICAL_STRUCTURE §13): <brand>-shelfwise[.web.app], with -dev
  # in the dev project. Firebase site names are globally unique, so pass --site
  # when the default is already taken.
  if [[ "$BRAND" == *shelfwise* ]]; then SITE="$BRAND"; else SITE="$BRAND-shelfwise"; fi
  [[ "$ENV_NAME" == "prod" ]] || SITE="$SITE-dev"
  [[ ${#SITE} -le 30 ]] || die "site name \"$SITE\" is longer than Firebase's 30-character limit - pass --site <shorter-name>"
fi

step "Hosting site $SITE (project $PROJECT)"
if firebase hosting:sites:list --project "$PROJECT" --json 2>/dev/null | grep -q "\"$SITE\""; then
  echo "    site exists"
else
  echo "    creating site"
  firebase hosting:sites:create "$SITE" --project "$PROJECT"
fi
firebase target:apply hosting "$BRAND" "$SITE" --project "$PROJECT"

# --- 4. deploy ----------------------------------------------------------------
if [[ -n "$CHANNEL" ]]; then
  step "Deploying to preview channel \"$CHANNEL\" (expires in $EXPIRES)"
  firebase hosting:channel:deploy "$CHANNEL" \
    --only "$BRAND" \
    --expires "$EXPIRES" \
    --project "$PROJECT"
else
  step "Deploying to live"
  firebase deploy --only "hosting:$BRAND" --project "$PROJECT"
  echo
  echo "Live: https://$SITE.web.app"
fi
