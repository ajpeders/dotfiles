#!/usr/bin/env bash
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃              Battery-aware hypridle launcher                 ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
# Runs hypridle with relaxed timeouts on AC and aggressive ones on battery,
# and swaps live when you plug/unplug. Started from hypr/config/autostart.lua.
#
# NOTE: hypridle 0.1.7's -c/--config flag is broken (it ignores the path and
# only searches the default locations), so we can't just point hypridle at a
# variant. Instead we symlink the chosen variant to the default config path
# (hypr/hypridle.conf, gitignored) and launch hypridle with no args.
#
# Any Mains-type power supply with online=1 means AC (macsmc-ac on Asahi,
# AC/ADP1 on x86 laptops). A machine with no battery at all is always on AC,
# so desktops get the relaxed profile and never idle-suspend.
# We re-check on every UPower event but only restart hypridle when the AC
# state actually flips — restarting resets the idle timer, so we avoid doing
# it on unrelated events (e.g. battery-percentage updates).
set -u

HYPR_DIR="$HOME/.config/hypr"
ACTIVE="$HYPR_DIR/hypridle.conf"   # generated symlink that hypridle actually reads

has_battery() {
    grep -qs '^Battery$' /sys/class/power_supply/*/type 2>/dev/null
}
on_ac() {
    has_battery || return 0
    local ps
    for ps in /sys/class/power_supply/*; do
        [ "$(cat "$ps/type" 2>/dev/null)" = "Mains" ] || continue
        [ "$(cat "$ps/online" 2>/dev/null)" = "1" ] && return 0
    done
    return 1
}

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
