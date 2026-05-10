#!/bin/bash
# macOS dotfiles bootstrap.
# Usage: bash macos/install.sh
# Run from within the cloned dotfiles repo as a non-root user.
# Safe to re-run.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }
print_phase() { echo -e "\n${BOLD}== $1 ==${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

phase_preflight() {
    print_phase "Phase 1: Preflight"

    if [[ "$(uname)" != "Darwin" ]]; then
        print_error "This script targets macOS. Use install.sh for Arch Linux."
        exit 1
    fi
    print_status "Running on macOS"

    if [ "$EUID" -eq 0 ]; then
        print_error "Do not run as root."
        exit 1
    fi
    print_status "Running as: $USER"

    print_info "This script will:"
    echo "  - Install Homebrew if missing"
    echo "  - Install AeroSpace (tiling WM) and kitty"
    echo "  - Symlink macOS configs into ~/.config and ~/Library/LaunchAgents"
    echo "  - Print follow-up instructions for SMB Keychain seeding"
    echo ""
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
}

phase_brew() {
    print_phase "Phase 2: Homebrew"

    if command -v brew >/dev/null 2>&1; then
        print_status "Homebrew already installed"
        return
    fi

    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    print_status "Homebrew installed"
}

phase_packages() {
    print_phase "Phase 3: Packages"

    if brew list --cask aerospace >/dev/null 2>&1; then
        print_status "AeroSpace already installed"
    else
        print_info "Installing AeroSpace..."
        brew install --cask nikitabobko/tap/aerospace
        print_status "AeroSpace installed"
    fi

    if brew list --cask kitty >/dev/null 2>&1; then
        print_status "kitty already installed"
    else
        print_info "Installing kitty..."
        brew install --cask kitty
        print_status "kitty installed"
    fi
}

phase_dotfiles() {
    print_phase "Phase 4: Dotfiles"

    mkdir -p "$HOME/.config" "$HOME/Library/LaunchAgents"

    link() {
        local src="$1"
        local dst="$2"
        local name
        name="$(basename "$dst")"

        if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
            print_status "Already linked: $name"
            return
        fi

        if [ -e "$dst" ] || [ -L "$dst" ]; then
            local backup="${dst}.backup.$(date +%Y%m%d_%H%M%S)"
            mv "$dst" "$backup"
            print_info "Backed up existing $name to $backup"
        fi

        ln -sfn "$src" "$dst"
        print_status "Linked: $name"
    }

    link "$SCRIPT_DIR/aerospace" "$HOME/.config/aerospace"
    link "$REPO_DIR/kitty" "$HOME/.config/kitty"
    link "$SCRIPT_DIR/com.alex.mount.share.plist" "$HOME/Library/LaunchAgents/com.alex.mount.share.plist"
}

phase_launchagents() {
    print_phase "Phase 5: LaunchAgents"

    local plist="$HOME/Library/LaunchAgents/com.alex.mount.share.plist"
    if launchctl list | grep -q com.alex.mount.share; then
        print_status "SMB mount agent already loaded"
    else
        launchctl load "$plist"
        print_status "SMB mount agent loaded"
    fi
}

phase_reminders() {
    print_phase "Done"

    echo ""
    echo -e "${GREEN}Installation complete.${NC} Manual follow-ups:"
    echo ""
    echo -e "${BOLD}1. Seed Keychain with the SMB password${NC}"
    echo "   /usr/bin/security add-internet-password -a ween -s share.thelunadog.com -r 'smb ' -w"
    echo ""
    echo -e "${BOLD}2. Grant kitty Full Disk Access${NC}"
    echo "   System Settings → Privacy & Security → Full Disk Access → add kitty.app"
    echo "   (Required to read /Volumes/share from the terminal.)"
    echo ""
    echo -e "${BOLD}3. Trigger SMB mount${NC}"
    echo "   launchctl start com.alex.mount.share"
    echo ""
    echo -e "${BOLD}4. (Optional) symlink the share to home${NC}"
    echo "   ln -s /Volumes/share ~/share"
    echo ""
    echo -e "${BOLD}5. Start AeroSpace${NC}"
    echo "   open -a AeroSpace"
    echo ""
}

phase_preflight
phase_brew
phase_packages
phase_dotfiles
phase_launchagents
phase_reminders
