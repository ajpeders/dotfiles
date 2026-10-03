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
for launcher in opencode-local opencode-cloud opencode-hybrid hq; do
    unlink_if_managed "$REPO_DIR/scripts/$launcher" "$HOME/.local/bin/$launcher"
done

print_info "Kept packages, enabled services, ~/.zshenv, backups and $REPO_DIR."
