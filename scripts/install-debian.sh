#!/bin/bash
# Debian headless dotfiles bootstrap (apt).
# Usage: bash scripts/install-debian.sh
# Run from within the cloned dotfiles repo as a non-root user.
# Safe to re-run: each phase checks whether its work is already done.
#
# This is the Debian counterpart to the Arch `scripts/install.sh --headless`. There is
# no full-desktop mode: the GUI stack (Hyprland, Noctalia, ly, ...) is
# Arch-only, so on Debian this script is headless, always. It installs the CLI
# base via apt, links the shared CLI dotfiles, sets up zsh + oh-my-zsh +
# powerlevel10k, and enables sshd.
#
# Package names differ from packages.txt (which is Arch/pacman-named), so the
# apt set is maintained here directly rather than parsed from that file.

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
# The repo root is one level up: this script lives in <repo>/scripts/.
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$HOME/.local/state/dotfiles-mode"

# CLI base, Debian/apt names. Kept in sync with the "Headless / CLI base"
# section of packages.txt in spirit, but named for apt:
#   Arch github-cli -> gh (only in trixie+/GitHub apt repo; tolerated if absent)
#   Arch fd         -> fd-find      (binary fdfind; symlinked to ~/.local/bin/fd)
#   Arch openssh    -> openssh-server + openssh-client
#   Arch yazi/fastfetch may be absent on older Debian; failures are tolerated.
APT_PACKAGES=(
    zsh
    neovim
    git
    gh
    curl
    wget
    unzip
    rsync
    jq
    eza
    btop
    fastfetch
    imagemagick
    fd-find
    ripgrep
    fzf
    zoxide
    mosh
    openssh-server
    openssh-client
    tmux
    ca-certificates
)

case "${1:-}" in
    "") ;;
    --help|-h) sed -n '2,14p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) print_error "Unknown argument: $1 (try --help)"; exit 1 ;;
esac

phase_preflight() {
    print_phase "Phase 1: Preflight (HEADLESS)"

    if [ ! -f /etc/debian_version ]; then
        print_error "This script requires Debian/Ubuntu (/etc/debian_version not found)"
        print_error "On Arch, use: bash scripts/install.sh --headless"
        exit 1
    fi
    print_status "Running on Debian $(cat /etc/debian_version)"

    if [ "$EUID" -eq 0 ]; then
        print_error "Do not run as root; symlinks and shell changes must target your user"
        exit 1
    fi
    print_status "Running as non-root user: $USER"

    if ! command -v sudo >/dev/null 2>&1; then
        print_error "sudo not found; install it as root first (apt install sudo) and add $USER to it"
        exit 1
    fi

    if [ ! -d "$REPO_DIR/zsh" ]; then
        print_error "zsh/ not found; run this script from within the dotfiles repo (~/.config)"
        exit 1
    fi
    print_status "Dotfiles repo found at: $REPO_DIR"

    echo ""
    print_info "This script will:"
    echo "  - apt install the CLI base (zsh, neovim, git, mosh, openssh, tmux, ...)"
    echo "  - Link CLI dotfiles into ~/.config (zsh, nvim, tmux, yazi, git)"
    echo "  - Configure zsh, oh-my-zsh, plugins, and powerlevel10k"
    echo "  - Enable sshd (and NetworkManager/avahi-daemon if present)"
    echo ""
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
}

phase_packages() {
    print_phase "Phase 2: Packages (apt)"

    print_info "Updating package lists..."
    sudo apt-get update

    local failed=()
    print_info "Installing ${#APT_PACKAGES[@]} packages; already-installed packages are skipped..."
    local pkg
    for pkg in "${APT_PACKAGES[@]}"; do
        if sudo apt-get install -y --no-install-recommends "$pkg" >/dev/null 2>&1; then
            print_status "$pkg"
        else
            print_error "Failed to install: $pkg (skipping)"
            failed+=("$pkg")
        fi
    done

    if [ "${#failed[@]}" -gt 0 ]; then
        echo ""
        print_info "The following packages were not available via apt:"
        for pkg in "${failed[@]}"; do echo "  - $pkg"; done
        print_info "Install them manually if needed (e.g. yazi via cargo/binary, gh via GitHub's apt repo)."
    else
        print_status "All packages installed"
    fi

    # Debian ships fd as 'fdfind'; expose it as 'fd' on PATH for the shared aliases/config.
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        mkdir -p "$HOME/.local/bin"
        ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
        print_status "Symlinked fdfind -> ~/.local/bin/fd"
    fi
}

phase_directories() {
    print_phase "Phase 3: Directories"

    local dir
    for dir in "$HOME/.local/state" "$HOME/.local/bin"; do
        if [ -d "$dir" ]; then
            print_status "Already exists: $dir"
        else
            mkdir -p "$dir"
            print_status "Created: $dir"
        fi
    done
}

phase_dotfiles() {
    print_phase "Phase 4: Dotfiles"

    local config_dirs=(zsh yazi git tmux nvim opencode)
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
        if [ -d "$REPO_DIR/$dir" ]; then
            backup_and_link "$REPO_DIR/$dir" "$HOME/.config/$dir"
        fi
    done

    if [ ! -f "$HOME/.zshenv" ]; then
        printf 'export ZDOTDIR="$HOME/.config/zsh"\n' > "$HOME/.zshenv"
        print_status "Created ~/.zshenv with ZDOTDIR"
    elif grep -q 'ZDOTDIR=.*\.config/zsh' "$HOME/.zshenv"; then
        print_status "~/.zshenv already configures ZDOTDIR"
    else
        printf '\nexport ZDOTDIR="$HOME/.config/zsh"\n' >> "$HOME/.zshenv"
        print_status "Added ZDOTDIR to ~/.zshenv"
    fi

    if [ "$backed_up" = true ]; then
        print_info "Old configs backed up to: $backup_dir"
    fi
    print_status "Dotfiles linked"
}

phase_shell() {
    print_phase "Phase 5: Shell"

    local zsh_bin
    zsh_bin="$(command -v zsh || true)"
    if [ -z "$zsh_bin" ]; then
        print_error "zsh not installed; cannot set it as the default shell (skipping)"
        return
    fi

    if [ "${SHELL:-}" = "$zsh_bin" ]; then
        print_status "zsh already default shell"
    else
        if chsh -s "$zsh_bin"; then
            print_status "Default shell set to zsh; it takes effect on next login"
        else
            print_error "chsh failed; set it manually: chsh -s $zsh_bin"
        fi
    fi

    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_status "oh-my-zsh already installed"
    else
        print_info "Installing oh-my-zsh..."
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        print_status "oh-my-zsh installed"
    fi

    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    mkdir -p "$zsh_custom/plugins" "$zsh_custom/themes"

    if [ -d "$zsh_custom/plugins/zsh-autosuggestions" ]; then
        print_status "zsh-autosuggestions already installed"
    else
        git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
        print_status "zsh-autosuggestions installed"
    fi

    if [ -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]; then
        print_status "zsh-syntax-highlighting already installed"
    else
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting"
        print_status "zsh-syntax-highlighting installed"
    fi

    if [ -d "$zsh_custom/themes/powerlevel10k" ]; then
        print_status "powerlevel10k already installed"
    else
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$zsh_custom/themes/powerlevel10k"
        print_status "powerlevel10k installed"
    fi
}

phase_services() {
    print_phase "Phase 6: Services"

    enable_system_service() {
        local svc="$1"
        # Only touch units that actually exist on this box (Debian installs vary).
        if ! systemctl list-unit-files "${svc}.service" >/dev/null 2>&1 \
             || ! systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -q "${svc}.service"; then
            print_info "Not installed, skipping: $svc"
            return
        fi
        if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            print_status "Already enabled: $svc"
        else
            sudo systemctl enable "$svc"
            print_status "Enabled: $svc"
        fi
    }

    # Debian's OpenSSH server unit is 'ssh'; enable whichever this box has.
    if systemctl list-unit-files 2>/dev/null | grep -q '^ssh\.service'; then
        enable_system_service ssh
    else
        enable_system_service sshd
    fi
    enable_system_service NetworkManager
    enable_system_service avahi-daemon
}

phase_opencode() {
    print_phase "Phase 7: opencode"

    # Arch gets opencode from packages.txt and macOS from the Brewfile; Debian
    # has no package, so fall back to upstream's installer. It drops a static
    # binary in ~/.opencode/bin, which zsh/.zshrc adds to PATH when present.
    if command -v opencode >/dev/null 2>&1; then
        print_status "Already installed: opencode ($(opencode --version 2>/dev/null || echo 'version unknown'))"
        return
    fi

    if ! curl -fsSL https://opencode.ai/install | bash; then
        print_error "opencode install failed (non-fatal); install it later with:"
        print_error "  curl -fsSL https://opencode.ai/install | bash"
        return
    fi
    print_status "Installed: opencode"
}

phase_state() {
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "headless" > "$STATE_FILE"
}

phase_reminders() {
    print_phase "Done"

    echo ""
    echo -e "${GREEN}Debian headless install complete.${NC} Follow-ups:"
    echo ""
    echo -e "${BOLD}1. Configure your prompt${NC}"
    echo "   Open a new shell and run: p10k configure"
    echo ""
    echo -e "${BOLD}2. Verify sshd is reachable${NC}"
    echo "   systemctl status ssh"
    echo ""
    echo -e "${BOLD}3. Start a fresh login shell to pick up zsh${NC}"
    echo ""
}

phase_preflight
phase_packages
phase_directories
phase_dotfiles
phase_shell
phase_services
phase_opencode
phase_state
phase_reminders
