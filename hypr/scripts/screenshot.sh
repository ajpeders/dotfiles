#!/usr/bin/env bash
# Screenshots for Hyprland (Wayland): grim + slurp, optional swappy annotation.
#
#   screenshot.sh full      whole screen           -> file
#   screenshot.sh window    focused window         -> clipboard
#   screenshot.sh region    drag a region          -> file
#   screenshot.sh copy      drag a region          -> clipboard only
#   screenshot.sh annotate  drag a region          -> swappy, saves back on exit
#
# A cancelled region grab (Esc) exits 0 with no output and no notification,
# so the keybind never flashes an error. Override the target with
# SCREENSHOT_DIR.
set -euo pipefail

dir="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
mode="${1:-full}"

notify() { # icon title body
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a Screenshot -i "$1" "$2" "$3" 2>/dev/null || true
}

mkdir -p "$dir"
stamp="$(date +'%Y-%m-%d-%H%M%S')"
file="$dir/${stamp}_screenshot.png"

case "$mode" in
    full)
        grim "$file"
        notify camera-photo "Screenshot" "Saved ${stamp}_screenshot.png"
        ;;
    window)
        geom=$(hyprctl activewindow -j | jq -r 'select(.at) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"') || exit 0
        [ -n "$geom" ] || exit 0
        grim -g "$geom" - | wl-copy
        notify edit-copy "Screenshot" "Window copied to clipboard"
        ;;
    region)
        geom="$(slurp)" || exit 0
        [ -n "$geom" ] || exit 0
        grim -g "$geom" "$file"
        notify camera-photo "Screenshot" "Saved ${stamp}_screenshot.png"
        ;;
    copy)
        geom="$(slurp)" || exit 0
        [ -n "$geom" ] || exit 0
        grim -g "$geom" - | wl-copy
        notify edit-copy "Screenshot" "Region copied to clipboard"
        ;;
    annotate)
        geom="$(slurp)" || exit 0
        [ -n "$geom" ] || exit 0
        grim -g "$geom" "$file"
        swappy -f "$file" -o "$file"
        ;;
    *)
        echo "usage: ${0##*/} {full|window|region|copy|annotate}" >&2
        exit 2
        ;;
esac