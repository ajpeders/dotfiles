#!/bin/bash
# Remove only symlinks created by macos/install.sh.
# Packages, Keychain entries, backups, ~/.zshenv and the repository are kept.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ "$(uname)" != "Darwin" ]; then
    echo "Use scripts/uninstall.sh on Linux." >&2
    exit 1
fi

unlink_if_managed() {
    local src="$1" dst="$2"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        unlink "$dst"
        echo "Unlinked: $dst"
    fi
}

for agent in com.alex.mount.share com.alex.tailscale; do
    plist="$HOME/Library/LaunchAgents/$agent.plist"
    if [ -L "$plist" ] && [ "$(readlink "$plist")" = "$SCRIPT_DIR/$agent.plist" ]; then
        # Stop only our loaded agent; leave unrelated agents alone.
        launchctl bootout "gui/$(id -u)/$agent" 2>/dev/null || true
        unlink "$plist"
        echo "Unlinked: $plist"
    fi
done

unlink_if_managed "$SCRIPT_DIR/aerospace" "$HOME/.config/aerospace"
unlink_if_managed "$SCRIPT_DIR/mount-share.sh" "$HOME/.config/mount-share.sh"
for dir in kitty yazi zsh tmux opencode git nvim; do
    unlink_if_managed "$REPO_DIR/$dir" "$HOME/.config/$dir"
done
for launcher in opencode-local opencode-cloud opencode-hybrid hq; do
    unlink_if_managed "$REPO_DIR/scripts/$launcher" "$HOME/.local/bin/$launcher"
done

echo "Kept Homebrew packages, Keychain entries, ~/.zshenv, backups and $REPO_DIR."
