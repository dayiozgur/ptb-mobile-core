#!/usr/bin/env bash
# simtap.sh <device_x> <device_y>
# Tap the booted iOS Simulator at DEVICE-PIXEL coordinates (screenshot space).
# Device screen = 1206x2622 (iPhone 17 Pro). Fits the device into the live
# Simulator window content (min-scale, centered on BOTH axes) → works whether
# "Show Device Bezels" is on or off. Maps device px -> screen point, then cliclick.
set -euo pipefail
DEV_W=1206; DEV_H=2622
TB=${SIMTAP_TB:-28}   # macOS title bar height (override with SIMTAP_TB if needed)
DX=$1; DY=$2
geo=$(osascript -e 'tell application "System Events" to tell process "Simulator" to get {position, size} of window 1')
WX=$(echo "$geo" | cut -d, -f1 | tr -d ' ')
WY=$(echo "$geo" | cut -d, -f2 | tr -d ' ')
WW=$(echo "$geo" | cut -d, -f3 | tr -d ' ')
WH=$(echo "$geo" | cut -d, -f4 | tr -d ' ')
# Available content area (below the title bar).
AVW=$WW
AVH=$((WH - TB))
# Min-scale fit (×1000 for integer math), then center on both axes.
SXscale=$(( AVW * 1000 / DEV_W ))
SYscale=$(( AVH * 1000 / DEV_H ))
SCALE=$(( SXscale < SYscale ? SXscale : SYscale ))
SCRW=$(( DEV_W * SCALE / 1000 ))
SCRH=$(( DEV_H * SCALE / 1000 ))
ORIGIN_X=$(( WX + (WW - SCRW) / 2 ))
ORIGIN_Y=$(( WY + TB + (AVH - SCRH) / 2 ))
SX=$(( ORIGIN_X + DX * SCALE / 1000 ))
SY=$(( ORIGIN_Y + DY * SCALE / 1000 ))
osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
/opt/homebrew/bin/cliclick c:${SX},${SY}
echo "tap device(${DX},${DY}) -> screen(${SX},${SY})  [win ${WX},${WY} ${WW}x${WH} scale ${SCALE}/1000 screen ${SCRW}x${SCRH} origin ${ORIGIN_X},${ORIGIN_Y}]"
