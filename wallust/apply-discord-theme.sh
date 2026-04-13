#!/usr/bin/env sh
set -eu

SRC="$HOME/.cache/wallust/discord-vencord.css"

[ -f "$SRC" ] || exit 0

# Keep first target explicit for stock Discord + Vencord injection.
PRIMARY="$HOME/.config/discord/settings/quickCss.css"
mkdir -p "$(dirname "$PRIMARY")"
cp "$SRC" "$PRIMARY"

# Mirror to other common client locations when they exist.
for dir in \
  "$HOME/.config/discordcanary/settings" \
  "$HOME/.config/discordptb/settings" \
  "$HOME/.config/vesktop/settings" \
  "$HOME/.config/Vencord/settings" \
  "$HOME/.config/armcord/settings"
do
  if [ -d "$dir" ]; then
    cp "$SRC" "$dir/quickCss.css"
  fi
done
