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
DOTFILES_MIGRATIONS_DIR="$HOME/.local/state/dotfiles/migrations"
DOTFILES_STATE_DIR="$HOME/.local/state/dotfiles"
DOTFILES_DESKTOP_STATE="$DOTFILES_STATE_DIR/dotfiles-desktop"

# dotfiles_detect_desktop -- decide which desktop stack we are on.
# Single source of truth shared by install.sh and update.sh. Honors explicit
# overrides (--omarchy / --no-omarchy), then the omarchy package, then the
# on-disk dotfiles-desktop state file. Returns the string "omarchy" or
# "noctalia". Sets OMARCHY=1 or OMARCHY=0 in the caller for backwards
# compatibility with existing scripts.
#
# Usage:
#   dotfiles_detect_desktop            # auto-detect
#   OMARCHY=-1 dotfiles_detect_desktop # auto-detect (default sentinel)
#   OMARCHY=1  dotfiles_detect_desktop # forced Omarchy via flag
dotfiles_detect_desktop() {
    if [ "${OMARCHY:- -1}" != " -1" ] && [ "${OMARCHY:-}" != "-1" ]; then
        # Caller already set OMARCHY via --omarchy / --no-omarchy. Respect it.
        if [ "$OMARCHY" -eq 1 ]; then
            echo "omarchy"; return 0
        fi
        echo "noctalia"; return 0
    fi

    local detected="noctalia"
    if command -v pacman >/dev/null 2>&1 && pacman -Qq omarchy >/dev/null 2>&1; then
        detected="omarchy"
    elif [ -r "$DOTFILES_DESKTOP_STATE" ] && [ "$(cat "$DOTFILES_DESKTOP_STATE")" = "omarchy" ]; then
        detected="omarchy"
    fi

    if [ "$detected" = "omarchy" ]; then
        OMARCHY=1
    else
        OMARCHY=0
    fi
    echo "$detected"
}

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

# dotfiles_run_migration <name> <command...>
# Run a one-shot migration that is keyed by <name>. Skips when the marker
# already exists. Writes the marker only after the command exits 0.
dotfiles_run_migration() {
    local name="$1"; shift
    local marker="$DOTFILES_MIGRATIONS_DIR/$name"

    mkdir -p "$DOTFILES_MIGRATIONS_DIR"

    if [ -e "$marker" ]; then
        return 0
    fi

    echo -e "${YELLOW}[i]${NC} Running migration: $name"
    if "$@"; then
        : >"$marker"
        echo -e "${GREEN}[✓]${NC} Migration $name complete"
    else
        local rc=$?
        echo -e "${RED}[✗]${NC} Migration $name failed (exit $rc); will retry next run." >&2
        return "$rc"
    fi
}
