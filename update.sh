#!/bin/bash
# Arch Linux dotfiles update script.
# Usage: bash update.sh
# Run from within the dotfiles repo. Pulls latest changes and syncs everything.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error()  { echo -e "${RED}[✗]${NC} $1"; }
print_info()   { echo -e "${YELLOW}[i]${NC} $1"; }
print_phase()  { echo -e "\n${BOLD}== $1 ==${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

phase_pull() {
    print_phase "Phase 1: Pull Latest Changes"

    cd "$SCRIPT_DIR"

    if ! git diff --quiet || ! git diff --cached --quiet; then
        print_info "Uncommitted changes detected:"
        git status --short
        read -rp "Continue anyway? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
    fi

    local before
    before="$(git rev-parse HEAD)"
    git pull --ff-only
    local after
    after="$(git rev-parse HEAD)"

    if [ "$before" = "$after" ]; then
        print_status "Already up to date"
    else
        print_status "Updated $(git log --oneline "$before..$after" | wc -l) commit(s):"
        git log --oneline "$before..$after" | sed 's/^/  /'
    fi
}

phase_packages() {
    print_phase "Phase 2: Package Sync"

    if [ ! -f "$SCRIPT_DIR/packages.txt" ]; then
        print_error "packages.txt not found"
        return 1
    fi

    local pkgs=()
    local line
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [ -n "$line" ] || continue
        pkgs+=("$line")
    done < "$SCRIPT_DIR/packages.txt"

    if [ "${#pkgs[@]}" -eq 0 ]; then
        print_info "No packages in packages.txt"
        return
    fi

    print_info "Syncing ${#pkgs[@]} packages (new packages will be installed)..."
    if yay -S --needed --noconfirm "${pkgs[@]}"; then
        print_status "Packages up to date"
    else
        print_error "Package sync failed"
        return 1
    fi
}

phase_pull
phase_packages
