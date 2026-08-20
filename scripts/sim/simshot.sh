#!/usr/bin/env bash
# simshot.sh [out.png]
# Screenshot the currently-booted iOS Simulator. Prints the path.
set -euo pipefail
OUT=${1:-/tmp/simshot-$$.png}
UDID=$(xcrun simctl list devices booted 2>/dev/null | grep -oE '[0-9A-F-]{36}' | head -1)
[ -z "$UDID" ] && { echo "no booted simulator" >&2; exit 1; }
xcrun simctl io "$UDID" screenshot "$OUT" >/dev/null 2>&1
echo "$OUT"
