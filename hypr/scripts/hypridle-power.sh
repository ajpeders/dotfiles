#!/usr/bin/env bash
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃              Battery-aware hypridle launcher                 ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
# Runs hypridle with relaxed timeouts on AC and aggressive ones on battery,
# and swaps live when you plug/unplug. Started from hypr/config/autostart.conf.
#
# NOTE: hypridle 0.1.7's -c/--config flag is broken (it ignores the path and
# only searches the default locations), so we can't just point hypridle at a
# variant. Instead we symlink the chosen variant to the default config path
# (hypr/hypridle.conf, gitignored) and launch hypridle with no args.
#
# macsmc-ac/online is 1 on AC, 0 on battery (Apple Silicon / Asahi).
# We re-check on every UPower event but only restart hypridle when the AC
# state actually flips — restarting resets the idle timer, so we avoid doing
# it on unrelated events (e.g. battery-percentage updates).
set -u

HYPR_DIR="$HOME/.config/hypr"
ACTIVE="$HYPR_DIR/hypridle.conf"   # generated symlink that hypridle actually reads
AC_ONLINE=/sys/class/power_supply/macsmc-ac/online

on_ac() { [ "$(cat "$AC_ONLINE" 2>/dev/null)" = "1" ]; }

apply() {
    pkill -x hypridle 2>/dev/null
    if on_ac; then
        ln -sf hypridle-ac.conf "$ACTIVE"
    else
        ln -sf hypridle-battery.conf "$ACTIVE"
    fi
    hypridle &
}

last=""
sync() {
    local now
    now=$(on_ac && echo ac || echo bat)
    [ "$now" = "$last" ] && return
    last=$now
    apply
}

# Start with the correct profile, then follow power-state changes.
sync
upower --monitor 2>/dev/null | while read -r _; do sync; done
