#!/bin/bash

set -euo pipefail

force=0
[ "${1:-}" = "--force" ] && force=1

if [ -x /usr/bin/matugen ]; then
  matugen_bin=/usr/bin/matugen
else
  matugen_bin="$(command -v matugen 2>/dev/null || true)"
fi
if [ -z "$matugen_bin" ] && [ -x "$HOME/.local/bin/matugen" ]; then
  matugen_bin="$HOME/.local/bin/matugen"
fi
[ -n "$matugen_bin" ] || exit 0
command -v omarchy >/dev/null 2>&1 || exit 0

background="$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)"
theme_name="$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)"
if [ ! -f "$background" ] || [ -z "$theme_name" ]; then
  exit 0
fi

lock="${XDG_RUNTIME_DIR:-/tmp}/omarchy-wallpaper-colors.lock"
exec 9>"$lock"
flock -n 9 || exit 0

state="$HOME/.local/state/omarchy/wallpaper-colors.background"
if [ "$force" -ne 1 ] && [ -f "$state" ] && [ "$(cat "$state")" = "$background" ]; then
  exit 0
fi

config="$HOME/.config/omarchy/matugen/config.toml"
generated="$HOME/.cache/omarchy/wallpaper-colors.toml"
overlay="$HOME/.config/omarchy/themes/$theme_name/colors.toml"

# Leave user-authored themes and explicit color overrides alone.
[ -d "/usr/share/omarchy/themes/$theme_name" ] || exit 0
if [ -f "$overlay" ] && ! grep -q '^# Generated from the active wallpaper by matugen\.' "$overlay"; then
  exit 0
fi

mkdir -p "$(dirname "$generated")" "$(dirname "$overlay")"
"$matugen_bin" image "$background" \
  --config "$config" \
  --type scheme-vibrant \
  --mode dark \
  --prefer saturation \
  --quiet

printf '%s\n' "$background" > "$state"

# Do not recursively refresh when this script is called by the theme-set hook.
if [ -f "$overlay" ] && cmp -s "$generated" "$overlay"; then
  exit 0
fi

install -m644 "$generated" "$overlay"
OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy theme set "$theme_name"
