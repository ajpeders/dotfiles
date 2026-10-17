#!/bin/bash
# Remove only symlinks created by the Arch dotfiles installer.
# Packages, services, backups, ~/.zshenv and the repository are left untouched.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib-dotfiles.sh
source "$SCRIPT_DIR/lib-dotfiles.sh"

if [ "$(uname)" != "Linux" ]; then
    print_error "Use macos/uninstall.sh on macOS."
    exit 1
fi

unlink_if_managed() {
    local src="$1" dst="$2"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        unlink "$dst"
        print_status "Unlinked: $dst"
    fi
}

for dir in "${DOTFILES_CLI_DIRS[@]}" "${DOTFILES_DESKTOP_DIRS[@]}"; do
    unlink_if_managed "$REPO_DIR/$dir" "$HOME/.config/$dir"
done
# Mirror the installer's launcher list: everything matching scripts/opencode-*,
# plus scripts/hq and scripts/jetshell. Iterate from disk so the unlink set
# tracks new launchers without editing this file.
for launcher in "$REPO_DIR/scripts"/opencode-* "$REPO_DIR/scripts"/hq "$REPO_DIR/scripts"/jetshell; do
    if [ ! -e "$launcher" ]; then
        continue
    fi
    unlink_if_managed "$launcher" "$HOME/.local/bin/$(basename "$launcher")"
done

print_info "Kept packages, enabled services, ~/.zshenv, backups and $REPO_DIR."
