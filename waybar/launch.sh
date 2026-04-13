#!/usr/bin/env bash
# Restart waybar. Kills any running instances first.

exec 200>/tmp/waybar-launch.lock
flock -n 200 || exit 0

killall waybar 2>/dev/null || true
sleep 0.5
waybar &

flock -u 200
exec 200>&-
