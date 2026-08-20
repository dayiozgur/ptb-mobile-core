# Simulator control — assistant dev-loop

Tooling so an AI assistant (or you) can **drive + inspect** the running iOS
Simulator from the CLI, to verify mobile developments in real time without
hand-driving every tap.

## What it gives
- **See** — `simshot.sh` grabs a screenshot of the booted simulator.
- **Drive** — `simtap.sh <x> <y>` taps at DEVICE-PIXEL coordinates (screenshot
  space), by mapping to the live Simulator window and clicking via `cliclick`.
- **Logs** — read the `flutter run` stdout (task output) for `flutter:` lines,
  `GoRouter` routes, exceptions.
- **Rebuild** — `flutter run -d <sim> --debug` (incremental ≈ 8 s), then re-shoot.

## One-time setup
```sh
brew install cliclick                     # click tool (5.x)
# Grant Terminal/host "Accessibility" + "Screen Recording" in System Settings >
# Privacy & Security, so osascript/cliclick may move the mouse + click.
```
(`idb` was evaluated but Facebook archived it and the `idb-companion` brew
formula is gone; `cliclick` + window-geometry mapping is the reliable path.)

## Usage
```sh
# screenshot
scripts/sim/simshot.sh /tmp/now.png

# tap at device coords (read them off a screenshot: iPhone 17 Pro = 1206x2622)
scripts/sim/simtap.sh 1064 2433     # e.g. bottom-nav "More"
```

## How the mapping works
`simtap.sh` reads the Simulator window frame with `osascript` (`{position,size}`
of window 1), assumes a ~28 px macOS title bar, fits the 1206×2622 device screen
**height-constrained** inside the content area (centered horizontally), and
maps `device(x,y) → screen(x,y)` before `cliclick c:sx,sy`.

- Device size is hardcoded to **iPhone 17 Pro (1206×2622)** — change `DEV_W/DEV_H`
  in `simtap.sh` for another device.
- Title-bar override: `SIMTAP_TB=NN scripts/sim/simtap.sh x y` if calibration drifts.

## Reliability notes
- **Top-level nav + buttons + list rows**: accurate (verified: bottom-nav →
  drawer, expand a menu group, alarm action buttons).
- **Near the very bottom edge / nested drawer children**: a few-px drift can
  make a tight target miss — nudge y or tap the row's icon; scroll first if the
  item is at a scroll fold.
- **Passwords**: the assistant does NOT type credentials into fields (policy) —
  a human enters the login password; everything after login can be driven here.
- The screenshot is device-pixels; the on-screen window is scaled — always read
  tap coords from a fresh `simshot.sh`, not from the scaled window.
