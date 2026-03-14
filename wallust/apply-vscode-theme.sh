#!/usr/bin/env sh
set -eu

SRC="$HOME/.cache/wallust/vscode-wallust.json"

apply_to_settings() {
  target="$1"

  [ -f "$SRC" ] || return 0

  target_dir=$(dirname "$target")
  mkdir -p "$target_dir"

  if [ ! -f "$target" ]; then
    printf '{}\n' > "$target"
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "wallust-vscode: jq is required to merge VS Code settings" >&2
    return 0
  fi

  if ! jq -e . "$target" >/dev/null 2>&1; then
    printf '{}\n' > "$target"
  fi

  tmp=$(mktemp)
  jq -s '
    . as $docs
    | ($docs[0] * $docs[1])
    | .["workbench.colorTheme"] = ($docs[1]["workbench.colorTheme"] // .["workbench.colorTheme"])
    | .["workbench.colorCustomizations"] = ($docs[1]["workbench.colorCustomizations"] // .["workbench.colorCustomizations"])
  ' "$target" "$SRC" > "$tmp"
  mv "$tmp" "$target"
}

apply_to_settings "$HOME/.config/Code/User/settings.json"
apply_to_settings "$HOME/.config/Code - OSS/User/settings.json"
