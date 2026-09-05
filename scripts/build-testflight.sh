#!/usr/bin/env bash
#
# build-testflight.sh — build one product app's release IPA and upload it to TestFlight.
#
# WHY a script (not CI): archive + upload need an Apple-authenticated environment —
# automatic signing downloads the distribution cert + App Store provisioning profile
# from your logged-in Apple Developer account (team 283AHKB4WM). Run this on YOUR Mac
# after signing into Xcode; it is not run headless in this repo.
#
# Prereqs (one-time, Apple side — see docs/testflight-release.md):
#   1. App registered in App Store Connect for the app's bundle id.
#   2. Signed into Xcode with an account on team 283AHKB4WM.
#   3. App Store Connect API key active. This repo ships the .p8 at
#      .secrets/AuthKey_79V5P3733J.p8 (key id 79V5P3733J, untracked). You supply the
#      ISSUER id (App Store Connect → Users and Access → Integrations → App Store Connect API).
#
# Usage:
#   ./scripts/build-testflight.sh <crm|phr|pms|ppm> <ASC_ISSUER_ID> [build_number]
#
# Example:
#   ./scripts/build-testflight.sh crm 69a6de70-XXXX-XXXX-XXXX-XXXXXXXXXXXX 2
#
set -euo pipefail

APP="${1:?usage: build-testflight.sh <crm|phr|pms|ppm> <ASC_ISSUER_ID> [build_number]}"
ISSUER="${2:?ASC issuer id required (App Store Connect → Users and Access → Integrations)}"
BUILD_NUMBER="${3:-}"

case "$APP" in
  crm|phr|pms|ppm) ;;
  *) echo "error: app must be one of crm|phr|pms|ppm (got '$APP')" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO_ROOT/example_$APP"
API_KEY_ID="9M78BB6JK8"
API_KEY_FILE="$REPO_ROOT/.secrets/AuthKey_${API_KEY_ID}.p8"

[ -d "$APP_DIR" ] || { echo "error: $APP_DIR not found" >&2; exit 1; }
[ -f "$API_KEY_FILE" ] || { echo "error: API key missing at $API_KEY_FILE" >&2; exit 1; }

# altool looks up the key by id under these dirs; stage it so we don't depend on ~/.appstoreconnect.
export API_PRIVATE_KEYS_DIR="$REPO_ROOT/.secrets"

echo "▸ [$APP] flutter pub get + pod install"
cd "$APP_DIR"
flutter pub get
( cd ios && pod install )

BUILD_ARG=()
if [ -n "$BUILD_NUMBER" ]; then
  # Second and later uploads of the same version need a higher build number.
  BUILD_ARG=(--build-number "$BUILD_NUMBER")
  echo "▸ [$APP] build number → $BUILD_NUMBER"
fi

echo "▸ [$APP] flutter build ipa (release, ExportOptions.plist)"
flutter build ipa --release \
  --export-options-plist=ios/ExportOptions.plist \
  "${BUILD_ARG[@]}"

IPA="$(ls -t "$APP_DIR"/build/ios/ipa/*.ipa 2>/dev/null | head -1)"
[ -n "$IPA" ] || { echo "error: no IPA produced under build/ios/ipa" >&2; exit 1; }
echo "▸ [$APP] built: $IPA"

echo "▸ [$APP] validating with App Store Connect…"
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$API_KEY_ID" --apiIssuer "$ISSUER"

echo "▸ [$APP] uploading to TestFlight…"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$API_KEY_ID" --apiIssuer "$ISSUER"

echo "✔ [$APP] uploaded. It appears in App Store Connect → TestFlight after processing (~5–15 min)."
echo "  Export-compliance is pre-answered via ITSAppUsesNonExemptEncryption=false, so no manual prompt."
