#!/usr/bin/env bash
# simtap.sh <device_x> <device_y>
# Tap the booted iOS Simulator at DEVICE-PIXEL coordinates (screenshot space).
# Device screen = 1206x2622 (iPhone 17 Pro). Maps device px -> on-screen point
# using the live Simulator window geometry, then cliclick.
set -euo pipefail
DEV_W=1206; DEV_H=2622
TB=${SIMTAP_TB:-28}   # macOS title bar height (override with SIMTAP_TB if needed)
DX=$1; DY=$2
# {position, size} flattens to "WX, WY, WW, WH"
geo=$(osascript -e 'tell application "System Events" to tell process "Simulator" to get {position, size} of window 1')
WX=$(echo "$geo" | cut -d, -f1 | tr -d ' ')
WY=$(echo "$geo" | cut -d, -f2 | tr -d ' ')
WW=$(echo "$geo" | cut -d, -f3 | tr -d ' ')
WH=$(echo "$geo" | cut -d, -f4 | tr -d ' ')
CONTENT_H=$((WH - TB))
CONTENT_W=$(( CONTENT_H * DEV_W / DEV_H ))   # height-constrained fit
MARGIN_X=$(( (WW - CONTENT_W) / 2 ))
ORIGIN_X=$(( WX + MARGIN_X ))
ORIGIN_Y=$(( WY + TB ))
SX=$(( ORIGIN_X + DX * CONTENT_W / DEV_W ))
SY=$(( ORIGIN_Y + DY * CONTENT_H / DEV_H ))
/opt/homebrew/bin/cliclick c:${SX},${SY}
echo "tap device(${DX},${DY}) -> screen(${SX},${SY})  [win ${WX},${WY} ${WW}x${WH} content ${CONTENT_W}x${CONTENT_H}]"
