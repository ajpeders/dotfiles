#!/bin/bash
# Living-room Pi (Debian 13, bash) dotfiles: link this host profile's $HOME
# files. Links only — the repo's main install.sh is Arch-specific and does not
# apply here, so there is deliberately no --full mode.
#
# Usage, from the repo root (i.e. ~/.config):
#   bash hosts/livingroom-pi/install.sh
#
# Safe to re-run; replaced files are kept as <name>.pre-dotfiles.

set -euo pipefail

HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$HOST_DIR/../common.sh"

require_not_root

case "${1:-}" in
    "") ;;
    --help|-h) sed -n '2,9p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) err "Unknown argument: ${1} (try --help)"; exit 1 ;;
esac

info "Linking livingroom-pi \$HOME dotfiles from $HOST_DIR"
link_home .bashrc
link_home .profile
info "Done."
