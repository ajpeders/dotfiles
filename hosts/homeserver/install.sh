#!/bin/bash
# Headless homeserver install: link this host profile's $HOME dotfiles, then
# (optionally) run the repo's main bootstrap in --headless mode for packages,
# shell, and services. No GUI anything, ever.
#
# Usage, from the repo root (i.e. ~/.config):
#   bash hosts/homeserver/install.sh            # links only
#   bash hosts/homeserver/install.sh --full     # links + main install.sh --headless
#
# Safe to re-run. Anything in $HOME that would be replaced and is NOT already a
# symlink into this repo is backed up alongside itself as <name>.pre-dotfiles.

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${YELLOW}[i]${NC} $1"; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"

if [ "$EUID" -eq 0 ]; then
    err "Run as your user, not root — symlinks must land in your \$HOME"
    exit 1
fi

FULL=0
case "${1:-}" in
    --full) FULL=1 ;;
    "") ;;
    --help|-h) sed -n '2,12p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) err "Unknown argument: ${1} (try --help)"; exit 1 ;;
esac

link_home() {
    local name="$1"
    local src="$HERE/$name"
    local dst="$HOME/$name"
    if [ "$(readlink -f "$dst" 2>/dev/null)" = "$src" ]; then
        ok "$name already linked"
        return
    fi
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.pre-dotfiles"
        info "$name existed — backed up to $name.pre-dotfiles"
    fi
    ln -sfn "$src" "$dst"
    ok "$name -> hosts/homeserver/$name"
}

info "Linking homeserver \$HOME dotfiles from $HERE"
link_home .zshrc
link_home .gitconfig
link_home .bashrc

if [ "$FULL" -eq 1 ]; then
    info "Handing off to the main bootstrap (--headless)"
    bash "$REPO/install.sh" --headless
else
    info "Links done. For packages/shell/services on a fresh box:"
    info "  bash hosts/homeserver/install.sh --full"
fi
