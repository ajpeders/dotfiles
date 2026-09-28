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

next=$(( (pct + STEP) % 100 ))
# 100 % → 0 % when pct was 80 → 100 (100 % mod 100 = 0)
# but we want 80 → 100, then 100 → 0. Fix:
if [ "$pct" -ge 80 ]; then
    next=0
else
    next=$(( pct + STEP ))
fi

brightnessctl -d "$DEV" set "${next}%" -q
