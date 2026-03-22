#!/usr/bin/env sh

set -eu

target="${1:-}"

if [ -z "$target" ]; then
    exit 1
fi

active_workspace_json="$(hyprctl -j activeworkspace)"
workspaces_json="$(hyprctl -j workspaces)"

current_id="$(printf '%s\n' "$active_workspace_json" | jq -r '.id')"
current_name="$(printf '%s\n' "$active_workspace_json" | jq -r '.name')"

if [ "$current_name" = "$target" ]; then
    exit 0
fi

if printf '%s\n' "$workspaces_json" | jq -e --arg target "$target" '.[] | select(.name == $target)' >/dev/null; then
    hyprctl notify 2 2500 "rgb(ffaa00)" "Workspace $target already exists"
    exit 1
fi

hyprctl dispatch renameworkspace "$current_id" "$target"
