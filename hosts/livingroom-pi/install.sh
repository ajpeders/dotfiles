#!/bin/bash
# Living-room Pi (Debian 13, bash) dotfiles: link this host profile's $HOME
# files. The main Arch scripts/install.sh does not apply here; for the CLI base + shell
# on a fresh box, --full hands off to the repo's Debian bootstrap instead.
#
# Usage, from the repo root (i.e. ~/.config):
#   bash hosts/livingroom-pi/install.sh            # links only
#   bash hosts/livingroom-pi/install.sh --full     # links + scripts/install-debian.sh
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

info "Linking livingroom-pi \$HOME dotfiles from $HOST_DIR"
link_home .bashrc
link_home .profile

if [ "$FULL" -eq 1 ]; then
    info "Handing off to the Debian bootstrap (install-debian.sh)"
    bash "$REPO/scripts/install-debian.sh"
else
    info "Links done. For the CLI base + zsh/oh-my-zsh on a fresh box:"
    info "  bash hosts/livingroom-pi/install.sh --full"
fi
