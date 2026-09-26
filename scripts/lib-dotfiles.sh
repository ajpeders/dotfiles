#!/bin/bash
# Shared helpers for scripts/install.sh and scripts/update.sh.
# Sourced, never run directly.

# Prevent direct execution.
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
    echo "scripts/lib-dotfiles.sh is a library, not a script." >&2
    exit 1
fi

# Color codes, mirroring install.sh and update.sh. Defined here so consumers
# that source this library don't have to repeat them.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

DOTFILES_LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}"
DOTFILES_LOCK_PATH="$DOTFILES_LOCK_DIR/dotfiles.lock"

# dotfiles_acquire_lock -- grab a non-blocking flock on DOTFILES_LOCK_PATH.
# Sets DOTFILES_LOCK_FD in the caller; on failure, prints and exits.
dotfiles_acquire_lock() {
    mkdir -p "$DOTFILES_LOCK_DIR" 2>/dev/null || true
    exec {DOTFILES_LOCK_FD}>"$DOTFILES_LOCK_PATH"
    if ! flock -n "$DOTFILES_LOCK_FD"; then
        echo -e "${RED}[✗]${NC} Another dotfiles script is already running." >&2
        echo -e "${RED}[✗]${NC} If that is stale, remove $DOTFILES_LOCK_PATH." >&2
        exit 1
    fi
}

# dotfiles_release_lock -- close the FD set by dotfiles_acquire_lock.
dotfiles_release_lock() {
    if [[ -n "${DOTFILES_LOCK_FD:-}" ]]; then
        flock -u "$DOTFILES_LOCK_FD" 2>/dev/null || true
        exec {DOTFILES_LOCK_FD}>&- 2>/dev/null || true
        unset DOTFILES_LOCK_FD
    fi
}

