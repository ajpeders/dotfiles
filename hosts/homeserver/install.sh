#!/bin/bash
# Headless homeserver install: link this host profile's $HOME dotfiles, then
# (optionally) run the repo's main bootstrap in --headless mode for packages,
# shell, and services. No GUI anything, ever.
#
# Usage, from the repo root (i.e. ~/.config):
#   bash hosts/homeserver/install.sh            # links only
#   bash hosts/homeserver/install.sh --full     # links + main scripts/install.sh --headless
#
# Safe to re-run; replaced files are kept as <name>.pre-dotfiles.

set -euo pipefail

HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HOST_DIR/../.." && pwd)"
# shellcheck source=../common.sh
source "$HOST_DIR/../common.sh"

require_not_root

FULL=0
case "${1:-}" in
    --full) FULL=1 ;;
    "") ;;
    --help|-h) sed -n '2,10p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) err "Unknown argument: ${1} (try --help)"; exit 1 ;;
esac

info "Linking homeserver \$HOME dotfiles from $HOST_DIR"
link_home .zshrc
link_home .gitconfig
link_home .bashrc

if [ "$FULL" -eq 1 ]; then
    info "Handing off to the main bootstrap (--headless)"
    bash "$REPO/scripts/install.sh" --headless
else
    info "Links done. For packages/shell/services on a fresh box:"
    info "  bash hosts/homeserver/install.sh --full"
fi
