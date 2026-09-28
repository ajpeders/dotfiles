#!/usr/bin/env bash
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃           Keyboard backlight cycle (SUPER + K, B)            ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
# Each press steps the keyboard backlight up by STEP%.
# Wraps: 0 → 20 → 40 → 60 → 80 → 100 → 0 → …
set -eu

DEV=kbd_backlight
STEP=20   # percent per press

max=$(brightnessctl -d "$DEV" max)
cur=$(brightnessctl -d "$DEV" get)
pct=$(( cur * 100 / max ))

next=$(( pct + STEP ))
[ "$next" -gt 100 ] && next=0

brightnessctl -d "$DEV" set "${next}%" -q
