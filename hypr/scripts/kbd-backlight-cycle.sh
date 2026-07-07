#!/usr/bin/env bash
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃           Keyboard backlight cycle (SUPER + K)               ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
# Each press steps the keyboard backlight; it rises 0 -> 100% then falls
# 100 -> 0% (a triangle), reversing direction at each end.
# Direction is remembered across presses in a runtime state file.
set -eu

DEV=kbd_backlight
STEP=20   # percent per press
STATE="${XDG_RUNTIME_DIR:-/tmp}/kbd-backlight-dir"

max=$(brightnessctl -d "$DEV" max)
cur=$(brightnessctl -d "$DEV" get)
pct=$(( cur * 100 / max ))

dir=$(cat "$STATE" 2>/dev/null || echo up)

if [ "$dir" = "up" ]; then
    next=$(( pct + STEP ))
    if [ "$next" -ge 100 ]; then next=100; echo down > "$STATE"; fi
else
    next=$(( pct - STEP ))
    if [ "$next" -le 0 ]; then next=0; echo up > "$STATE"; fi
fi

brightnessctl -d "$DEV" set "${next}%" -q
