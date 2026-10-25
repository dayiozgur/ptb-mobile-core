#!/usr/bin/env bash
#
# build-release-android.sh — build one product app's release Android App Bundle,
# obfuscated, with Dart symbols split out (CRA A-08 release hardening).
#
# Signing: the Gradle release config of each app still uses the DEBUG key
# (`signingConfig = signingConfigs.getByName("debug")` in android/app/build.gradle.kts).
# Store uploads need a real upload key — configure it (key.properties, git-ignored)
# before publishing. This script never reads or creates signing material.
#
# Usage:
#   ./scripts/build-release-android.sh <crm|phr|pms|ppm> [build_number]
#
# Output:
#   example_<app>/build/app/outputs/bundle/release/app-release.aab
#   example_<app>/build/debug-info/android/<version>[-b<build>]/   ← archive with the release;
#   needed to symbolicate crashes: flutter symbolize -i <trace> -d <dir>/app.android-arm64.symbols
#
set -euo pipefail

APP="${1:?usage: build-release-android.sh <crm|phr|pms|ppm> [build_number]}"
BUILD_NUMBER="${2:-}"

case "$APP" in
  crm|phr|pms|ppm) ;;
  *) echo "error: app must be one of crm|phr|pms|ppm (got '$APP')" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO_ROOT/example_$APP"
[ -d "$APP_DIR" ] || { echo "error: $APP_DIR not found" >&2; exit 1; }
[ -f "$APP_DIR/.env" ] || { echo "error: $APP_DIR/.env missing (bundled asset; see .env.example)" >&2; exit 1; }

cd "$APP_DIR"
flutter pub get

APP_VERSION="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
SYMBOLS_DIR="$APP_DIR/build/debug-info/android/${APP_VERSION}${BUILD_NUMBER:+-b$BUILD_NUMBER}"
mkdir -p "$SYMBOLS_DIR"

BUILD_ARG=()
[ -n "$BUILD_NUMBER" ] && BUILD_ARG=(--build-number "$BUILD_NUMBER")

echo "▸ [$APP] flutter build appbundle (release, obfuscated)"
flutter build appbundle --release \
  --obfuscate --split-debug-info="$SYMBOLS_DIR" \
  ${BUILD_ARG[@]+"${BUILD_ARG[@]}"}  # bash 3.2-safe empty-array expansion

echo "✔ [$APP] bundle: $APP_DIR/build/app/outputs/bundle/release/app-release.aab"
echo "  Dart symbols: $SYMBOLS_DIR (archive with this release; not committed)"
