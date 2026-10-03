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
SMB_CONFIG="$HOME/.config/dotfiles/smb.env"

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
    echo "  - Install AeroSpace (tiling WM), kitty and Tailscale"
    echo "  - Symlink macOS configs into ~/.config and ~/Library/LaunchAgents"
    echo "  - Optionally configure an SMB mount if $SMB_CONFIG exists"
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
    print_phase "Phase 3: Packages (brew bundle)"

    if [ ! -f "$SCRIPT_DIR/Brewfile" ]; then
        print_error "Brewfile not found at $SCRIPT_DIR/Brewfile"
        exit 1
    fi

    print_info "Installing packages from Brewfile..."
    if brew bundle --file="$SCRIPT_DIR/Brewfile"; then
        print_status "Brewfile applied"
    else
        print_error "Some packages failed; review brew bundle output above"
    fi

    # WireGuard — Mac App Store (id 1451685025). 'mas' is included in the Brewfile.
    if command -v mas >/dev/null 2>&1 && mas list 2>/dev/null | grep -q '^1451685025'; then
        print_status "WireGuard already installed"
    elif command -v mas >/dev/null 2>&1; then
        print_info "Installing WireGuard from Mac App Store..."
        print_info "(Requires being signed in to the App Store.)"
        mas install 1451685025 || print_error "WireGuard install failed — sign in to App Store and run: mas install 1451685025"
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

    # macOS-only
    link "$SCRIPT_DIR/aerospace" "$HOME/.config/aerospace"
    if [ -r "$SMB_CONFIG" ]; then
        link "$SCRIPT_DIR/mount-share.sh" "$HOME/.config/mount-share.sh"
        link "$SCRIPT_DIR/com.alex.mount.share.plist" "$HOME/Library/LaunchAgents/com.alex.mount.share.plist"
    fi
    link "$SCRIPT_DIR/com.alex.tailscale.plist" "$HOME/Library/LaunchAgents/com.alex.tailscale.plist"

    # Cross-platform configs from the repo root
    link "$REPO_DIR/kitty" "$HOME/.config/kitty"
    link "$REPO_DIR/yazi" "$HOME/.config/yazi"
    link "$REPO_DIR/zsh" "$HOME/.config/zsh"
    link "$REPO_DIR/tmux" "$HOME/.config/tmux"
    link "$REPO_DIR/opencode" "$HOME/.config/opencode"
    link "$REPO_DIR/git" "$HOME/.config/git"
    link "$REPO_DIR/nvim" "$HOME/.config/nvim"

    # Launchers
    mkdir -p "$HOME/.local/bin"
    link "$REPO_DIR/scripts/opencode-local" "$HOME/.local/bin/opencode-local"
    link "$REPO_DIR/scripts/opencode-cloud" "$HOME/.local/bin/opencode-cloud"
    link "$REPO_DIR/scripts/hq" "$HOME/.local/bin/hq"
    link "$REPO_DIR/scripts/opencode-hybrid" "$HOME/.local/bin/opencode-hybrid"

    # ZDOTDIR so zsh reads ~/.config/zsh/.zshrc
    if [ ! -f "$HOME/.zshenv" ]; then
        printf 'export ZDOTDIR="$HOME/.config/zsh"\n' > "$HOME/.zshenv"
        print_status "Created ~/.zshenv with ZDOTDIR"
    elif grep -q 'ZDOTDIR=.*\.config/zsh' "$HOME/.zshenv"; then
        print_status "~/.zshenv already configures ZDOTDIR"
    else
        printf '\nexport ZDOTDIR="$HOME/.config/zsh"\n' >> "$HOME/.zshenv"
        print_status "Added ZDOTDIR to ~/.zshenv"
    fi
}

phase_shell() {
    print_phase "Phase 5: Shell (oh-my-zsh + plugins)"

    # zsh/.zshrc sources $ZSH/oh-my-zsh.sh and expects the theme and plugins
    # under $ZSH_CUSTOM, same layout as scripts/install.sh's phase_shell.
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_status "oh-my-zsh already installed"
    else
        print_info "Installing oh-my-zsh..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        print_status "oh-my-zsh installed"
    fi

    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local name url dst
    while read -r name url; do
        dst="$zsh_custom/$name"
        if [ -d "$dst" ]; then
            print_status "${name##*/} already installed"
        else
            git clone --depth=1 "$url" "$dst"
            print_status "${name##*/} installed"
        fi
    done <<'LIST'
plugins/zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
plugins/zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
plugins/fzf-tab https://github.com/Aloxaf/fzf-tab
themes/powerlevel10k https://github.com/romkatv/powerlevel10k.git
LIST

    # Editor for OpenCode's external editor prompt (Ctrl+X E)
    if ! grep -q 'export EDITOR=' "$HOME/.zshrc" 2>/dev/null; then
        printf '\n# Editor for OpenCode external editor (Ctrl+X E)\nexport EDITOR=nvim\n' >> "$HOME/.zshrc"
        print_status "Added EDITOR=nvim to ~/.zshrc"
    else
        print_status "EDITOR already set in ~/.zshrc"
    fi
}

phase_keychain() {
    print_phase "Phase 6: Keychain (SMB password)"

    if [ ! -r "$SMB_CONFIG" ]; then
        print_info "No SMB config; skipping share setup"
        return
    fi
    # shellcheck source=/dev/null
    . "$SMB_CONFIG"
    : "${SMB_HOST:?Set SMB_HOST in $SMB_CONFIG}"
    : "${SMB_USER:?Set SMB_USER in $SMB_CONFIG}"
    : "${SMB_SHARE:?Set SMB_SHARE in $SMB_CONFIG}"

    if /usr/bin/security find-internet-password -a "$SMB_USER" -s "$SMB_HOST" >/dev/null 2>&1; then
        print_status "SMB keychain entry already exists for $SMB_USER@$SMB_HOST"
        return
    fi

    print_info "No keychain entry found for $SMB_USER@$SMB_HOST."
    read -rp "Seed it now? You'll be prompted for the SMB password. [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Skipped. Seed later with:"
        printf '    /usr/bin/security add-internet-password -a %q -s %q -r '\''smb '\'' -w\n' "$SMB_USER" "$SMB_HOST"
        return
    fi

    if /usr/bin/security add-internet-password -a "$SMB_USER" -s "$SMB_HOST" -r 'smb ' -w; then
        print_status "Keychain entry added"
    else
        print_error "security command failed; run it manually after install"
    fi
}

phase_launchagents() {
    print_phase "Phase 7: LaunchAgents"

    # `launchctl load` is the deprecated legacy syntax and reports success even
    # when it does nothing. bootstrap/print target the GUI domain explicitly,
    # which is also what HOWTO.md documents for manual use.
    local domain="gui/$(id -u)"

    load_agent() {
        local label="$1"
        local plist="$HOME/Library/LaunchAgents/${label}.plist"

        if launchctl print "$domain/$label" >/dev/null 2>&1; then
            print_status "Already loaded: $label"
            return
        fi
        launchctl bootstrap "$domain" "$plist"
        print_status "Loaded: $label"
    }

    if [ -r "$SMB_CONFIG" ]; then
        load_agent com.alex.mount.share
    fi

    # Tailscale's standalone build ships TailscaleStartOnLogin=0 and registers no
    # login item, so this agent is what actually brings it up at login.
    if [ -d /Applications/Tailscale.app ]; then
        load_agent com.alex.tailscale
    else
        print_info "Tailscale.app not found; skipping its login agent"
    fi
}

phase_reminders() {
    print_phase "Done"

    echo ""
    echo -e "${GREEN}Installation complete.${NC} Manual follow-ups:"
    echo ""
    if [ -r "$SMB_CONFIG" ]; then
        echo -e "${BOLD}SMB share:${NC} Grant kitty Full Disk Access to read network volumes."
        echo "   Trigger mount: launchctl kickstart -k gui/\$(id -u)/com.alex.mount.share"
        echo ""
    fi
    echo -e "${BOLD}1. Start AeroSpace${NC}"
    echo "   open -a AeroSpace"
    echo ""
    echo -e "${BOLD}2. Sign in to Tailscale${NC}"
    echo "   Tailscale starts at login via com.alex.tailscale; on a fresh machine"
    echo "   authenticate once with: tailscale up"
    echo ""
    echo -e "${BOLD}3. Connect WireGuard (optional)${NC}"
    echo "   Open the WireGuard app and import a config from ~/.config/wireguard/"
    echo "   (or drag-and-drop the .conf onto the app)."
    echo ""
    if [ -r "$SMB_CONFIG" ]; then
        echo -e "${BOLD}Note:${NC} If you skipped the Keychain phase, seed it later with:"
        printf '   /usr/bin/security add-internet-password -a %q -s %q -r '\''smb '\'' -w\n' "$SMB_USER" "$SMB_HOST"
    fi
    echo ""
}

phase_preflight
phase_brew
phase_packages
phase_dotfiles
phase_shell
phase_keychain
phase_launchagents
phase_reminders
