#!/bin/bash
# Sync private files (wallpapers, SSH hosts, etc.) from a remote server.
# Usage: bash sync-private.sh [user@host]
# Run after install.sh on a fresh machine, or anytime to update private files.
# If no argument is provided, prompts for the SSH connection string.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

if [ $# -ge 1 ]; then
    SYNC_HOST="$1"
else
    read -rp "SSH connection (user@host): " SYNC_HOST
    if [ -z "$SYNC_HOST" ]; then
        print_error "No host provided"
        exit 1
    fi
fi

if ! command -v rsync >/dev/null 2>&1; then
    print_error "rsync not found; install it first"
    exit 1
fi

# Use absolute paths to bypass any ssh wrapper (e.g. kitty's ssh kitten)
SSH_BIN="$(command -v /usr/bin/ssh || command -v ssh)"
RSYNC_BIN="$(command -v rsync)"

# Test SSH connectivity
print_info "Testing SSH connection to $SYNC_HOST..."
if ! "$SSH_BIN" -o ConnectTimeout=10 "$SYNC_HOST" true; then
    print_error "Cannot connect to $SYNC_HOST — check SSH key/config and retry"
    exit 1
fi
print_status "SSH connection OK"

# Sync helper: sync_dir remote_src local_dest [extra rsync args...]
sync_dir() {
    local remote_src="$1"
    local local_dest="$2"
    shift 2
    local name
    name="$(basename "$local_dest")"

    if ! "$SSH_BIN" "$SYNC_HOST" "[ -d '$remote_src' ]" 2>/dev/null; then
        print_info "Remote path not found, skipping: $remote_src"
        return
    fi

    mkdir -p "$local_dest"
    print_info "Syncing $name from $SYNC_HOST:$remote_src..."
    "$RSYNC_BIN" -avz --progress -e "$SSH_BIN" "$@" "$SYNC_HOST:$remote_src" "$local_dest/"
    print_status "Synced: $name"
}

# Wallpapers
sync_dir "Pictures/Wallpapers/" "$HOME/Pictures/Wallpapers"

# SSH hosts
sync_dir ".ssh/config.d/" "$HOME/.ssh/config.d"

# Librewolf profile (extensions, bookmarks, settings — excluding caches)
# Local path differs per OS; remote source stays Linux-style.
if [[ "$(uname)" == "Darwin" ]]; then
    LIBREWOLF_LOCAL="$HOME/Library/Application Support/librewolf"
else
    LIBREWOLF_LOCAL="$HOME/.config/librewolf"
fi
sync_dir ".config/librewolf/" "$LIBREWOLF_LOCAL" \
    --exclude="*/cache2/" \
    --exclude="*/Cache/" \
    --exclude="*/storage/default/" \
    --exclude="*/crashes/" \
    --exclude="*/datareporting/" \
    --exclude="*/saved-telemetry-pings/" \
    --exclude="*/thumbnails/"

print_status "Done"
