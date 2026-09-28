#!/bin/bash
# Sync private files (wallpapers, SSH hosts, etc.) from a remote server.
# Usage: bash scripts/sync-private.sh [user@host]
# Run after scripts/install.sh on a fresh machine, or anytime to update private files.
# If no argument is provided, tries luna on the LAN, then over Tailscale, and
# only prompts if neither answers. (Raw addresses, not the luna-alex alias: on a
# fresh machine the alias doesn't exist until this script has synced it.)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

DEFAULT_HOSTS=("alex@192.168.0.40" "alex@100.84.247.20")  # luna: LAN, Tailscale
SYNC_HOST="${1:-}"

if ! command -v rsync >/dev/null 2>&1; then
    print_error "rsync not found; install it first"
    exit 1
fi

# Use absolute paths to bypass any ssh wrapper (e.g. kitty's ssh kitten)
SSH_BIN="$(command -v /usr/bin/ssh || command -v ssh)"
RSYNC_BIN="$(command -v rsync)"

if [ -z "$SYNC_HOST" ]; then
    for candidate in "${DEFAULT_HOSTS[@]}"; do
        print_info "Trying $candidate..."
        if "$SSH_BIN" -o ConnectTimeout=3 -o BatchMode=yes "$candidate" true 2>/dev/null; then
            SYNC_HOST="$candidate"
            break
        fi
    done
fi
if [ -z "$SYNC_HOST" ]; then
    read -rp "SSH connection (user@host): " SYNC_HOST
    if [ -z "$SYNC_HOST" ]; then
        print_error "No host provided"
        exit 1
    fi
fi

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

# Sync helper for a single file: sync_file remote_src local_dest [extra rsync args...]
# An existing local file that differs is kept as <local_dest>.bak.
sync_file() {
    local remote_src="$1"
    local local_dest="$2"
    shift 2

    if ! "$SSH_BIN" "$SYNC_HOST" "[ -f '$remote_src' ]" 2>/dev/null; then
        print_info "Remote file not found, skipping: $remote_src"
        return
    fi

    mkdir -p "$(dirname "$local_dest")"
    print_info "Syncing $(basename "$local_dest") from $SYNC_HOST:$remote_src..."
    "$RSYNC_BIN" -avz --backup --suffix=.bak -e "$SSH_BIN" "$@" "$SYNC_HOST:$remote_src" "$local_dest"
    print_status "Synced: $local_dest"
}

# Wallpapers
sync_dir "Pictures/Wallpapers/" "$HOME/Pictures/Wallpapers"

# SSH hosts: shared host definitions live in luna's ~/.ssh/config.d/ (with
# Tailscale fallback). Each machine's own ~/.ssh/config is never overwritten,
# since isis and the Macs use per-machine keys there. The drop-ins are inert
# unless ~/.ssh/config includes them, and ssh_config is first-match-wins, so the
# Include has to lead the file for the shared definitions to beat any stale
# local block.
ensure_ssh_include() {
    local cfg="$HOME/.ssh/config"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    [ -f "$cfg" ] || : > "$cfg"

    if grep -qE '^[[:space:]]*Include[[:space:]]+.*\.ssh/config\.d/' "$cfg"; then
        return
    fi

    { printf 'Include ~/.ssh/config.d/*\n\n'; cat "$cfg"; } > "$cfg.new"
    mv "$cfg.new" "$cfg"
    chmod 600 "$cfg"
    print_status "Added 'Include ~/.ssh/config.d/*' to $cfg"
}

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
sync_dir ".ssh/config.d/" "$HOME/.ssh/config.d" --chmod=D700,F600
ensure_ssh_include

# Secrets that are portable between machines, unlike host identity (sunshine /
# wayvnc pairing keys, the SSH host key) which must stay per-machine.
# --chmod pins the local mode regardless of how the remote stores them.

# rclone remotes + OAuth refresh tokens
sync_dir ".config/rclone/" "$HOME/.config/rclone" --chmod=D700,F600

# WireGuard/AmneziaWG client configs (hold private keys) — see HOWTO.md#vpn
sync_dir ".config/wireguard/" "$HOME/.config/wireguard" --chmod=D700,F600

# GitHub CLI auth token (hosts.yml) + config
sync_dir ".config/gh/" "$HOME/.config/gh" --chmod=D700,F600

# Librewolf profile (extensions, bookmarks, settings — excluding caches)
# Local path differs per OS; remote source stays Linux-style.
#
# compatibility.ini records the Librewolf version that last opened the profile.
# Syncing it across hosts on different Librewolf versions makes the lower one
# refuse to start ("You've launched an older version of Librewolf"), so each
# host keeps its own. Lock files are per-run state and never worth copying.
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
    --exclude="*/thumbnails/" \
    --exclude="*/compatibility.ini" \
    --exclude="*/.parentlock" \
    --exclude="*/lock"

print_status "Done"
