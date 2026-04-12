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

phase_dotfiles() {
    print_phase "Phase 3: Dotfile Sync"

    local config_dirs=(hypr kitty waybar theme rofi wallust gtk-3.0 gtk-4.0 zsh)
    local config_files=(pavucontrol.ini QtProject.conf)
    local backup_dir="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    local backed_up=false

    mkdir -p "$HOME/.config"

    backup_and_link() {
        local src="$1"
        local dst="$2"
        local name
        name="$(basename "$dst")"

        local resolved_src resolved_dst
        resolved_src="$(readlink -f "$src")"
        resolved_dst="$(readlink -f "$dst" 2>/dev/null || true)"
        if [ "$resolved_src" = "$resolved_dst" ]; then
            print_status "Already in place: $name"
            return
        fi

        if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
            print_status "Already linked: $name"
            return
        fi

        if [ -e "$dst" ] || [ -L "$dst" ]; then
            mkdir -p "$backup_dir"
            mv "$dst" "$backup_dir/"
            backed_up=true
            print_info "Backed up existing $name to $backup_dir/"
        fi

        ln -sfn "$src" "$dst"
        print_status "Linked: $name"
    }

    local dir
    for dir in "${config_dirs[@]}"; do
        [ -d "$SCRIPT_DIR/$dir" ] && backup_and_link "$SCRIPT_DIR/$dir" "$HOME/.config/$dir"
    done

    local file
    for file in "${config_files[@]}"; do
        [ -f "$SCRIPT_DIR/$file" ] && backup_and_link "$SCRIPT_DIR/$file" "$HOME/.config/$file"
    done

    # Ensure ~/.zshenv is configured
    if [ ! -f "$HOME/.zshenv" ]; then
        printf 'export ZDOTDIR="$HOME/.config/zsh"\n' > "$HOME/.zshenv"
        print_status "Created ~/.zshenv with ZDOTDIR"
    elif ! grep -q 'ZDOTDIR=.*\.config/zsh' "$HOME/.zshenv"; then
        printf '\nexport ZDOTDIR="$HOME/.config/zsh"\n' >> "$HOME/.zshenv"
        print_status "Added ZDOTDIR to ~/.zshenv"
    else
        print_status "~/.zshenv already configured"
    fi

    if [ "$backed_up" = true ]; then
        print_info "Old configs backed up to: $backup_dir"
    fi
    print_status "Dotfiles in sync"
}

phase_reload() {
    print_phase "Phase 4: Live Reload"

    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        print_info "Not inside a Hyprland session — skipping live reload"
        print_info "Changes will take effect after next login"
        return
    fi

    # Hyprland
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 && print_status "Hyprland reloaded" \
            || print_error "hyprctl reload failed (non-fatal)"
    fi

    # Waybar
    if pgrep -x waybar >/dev/null 2>&1; then
        killall -SIGUSR2 waybar >/dev/null 2>&1 && print_status "Waybar reloaded" \
            || print_error "Waybar reload failed (non-fatal)"
    fi

    # Mako
    if pgrep -x mako >/dev/null 2>&1; then
        makoctl reload >/dev/null 2>&1 && print_status "Mako reloaded" \
            || print_error "Mako reload failed (non-fatal)"
    fi

    print_status "Live reload complete"
}

phase_pull
phase_packages
phase_dotfiles
phase_reload

echo ""
print_status "Update complete."
