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
#      .secrets/AuthKey_<KEY_ID>.p8 (key id = API_KEY_ID below, untracked). You supply the
#      ISSUER id (App Store Connect → Users and Access → Integrations → App Store Connect API).
#
# Usage:
#   ./scripts/build-testflight.sh <crm|phr|pms|ppm|fixflow> <ASC_ISSUER_ID> [build_number]
#
# PEM is not accepted yet: its Xcode project has no ios/ExportOptions.plist and points at a
# different DEVELOPMENT_TEAM than the other five apps (owner decision — see
# docs/store/STORE-READINESS-2026-11.md).
#
# Example:
#   ./scripts/build-testflight.sh crm 69a6de70-XXXX-XXXX-XXXX-XXXXXXXXXXXX 2
#
set -euo pipefail

APP="${1:?usage: build-testflight.sh <crm|phr|pms|ppm|fixflow> <ASC_ISSUER_ID> [build_number]}"
ISSUER="${2:?ASC issuer id required (App Store Connect → Users and Access → Integrations)}"
BUILD_NUMBER="${3:-}"

case "$APP" in
  crm|phr|pms|ppm|fixflow) ;;
  *) echo "error: app must be one of crm|phr|pms|ppm|fixflow (got '$APP')" >&2; exit 2 ;;
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

# CRA A-08: release builds are obfuscated; Dart symbols are split out so crash
# stack traces can still be symbolicated (`flutter symbolize -i <trace> -d <file>.symbols`).
# Keep SYMBOLS_DIR per release (archive it next to the IPA) — it is NOT committed
# (build/ is git-ignored).
APP_VERSION="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
SYMBOLS_DIR="$APP_DIR/build/debug-info/ios/${APP_VERSION}${BUILD_NUMBER:+-b$BUILD_NUMBER}"
mkdir -p "$SYMBOLS_DIR"

echo "▸ [$APP] flutter build ipa (release, obfuscated, ExportOptions.plist)"
flutter build ipa --release \
  --obfuscate --split-debug-info="$SYMBOLS_DIR" \
  --export-options-plist=ios/ExportOptions.plist \
  "${BUILD_ARG[@]}"
echo "▸ [$APP] Dart symbols: $SYMBOLS_DIR (archive with this release)"

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
