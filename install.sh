#!/bin/bash
# Arch Linux dotfiles bootstrap script.
# Usage: bash install.sh [--headless]
# Run from within the cloned dotfiles repo as a non-root user.
# Safe to re-run: each phase checks whether its work is already done.
#
# Modes:
#   (default)    Full Hyprland desktop install.
#   --headless   Skip GUI packages, desktop dotfiles, and the display manager.
#                Sets the system to multi-user.target and enables sshd.

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
GUI_MARKER_REGEX='^#[[:space:]]*===[[:space:]]*GUI'
STATE_FILE="$HOME/.local/state/dotfiles-mode"

HEADLESS=0
for arg in "$@"; do
    case "$arg" in
        --headless) HEADLESS=1 ;;
        --help|-h)
            sed -n '2,11p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            print_error "Unknown argument: $arg (try --help)"
            exit 1
            ;;
    esac
done

mode_label() {
    if [ "$HEADLESS" -eq 1 ]; then echo "HEADLESS"; else echo "FULL DESKTOP"; fi
}

phase_preflight() {
    print_phase "Phase 1: Preflight ($(mode_label))"

    if [ ! -f /etc/arch-release ]; then
        print_error "This script requires Arch Linux (/etc/arch-release not found)"
        exit 1
    fi
    print_status "Running on Arch Linux"

    if [ "$EUID" -eq 0 ]; then
        print_error "Do not run as root; symlinks and shell changes must target your user"
        exit 1
    fi
    print_status "Running as non-root user: $USER"

    if [ ! -f "$SCRIPT_DIR/packages.txt" ]; then
        print_error "packages.txt not found; run this script from within the dotfiles repo"
        exit 1
    fi
    print_status "Dotfiles repo found at: $SCRIPT_DIR"

    echo ""
    print_info "This script will:"
    echo "  - Install paru if needed"
    if [ "$HEADLESS" -eq 1 ]; then
        echo "  - Install headless packages from packages.txt (GUI packages skipped)"
        echo "  - Link CLI dotfiles into ~/.config (shell, editor, tmux, yazi, git)"
        echo "  - Configure zsh, oh-my-zsh, plugins, and powerlevel10k"
        echo "  - Enable NetworkManager, avahi-daemon, and sshd"
        echo "  - Set the system default target to multi-user.target (no graphical login)"
    else
        echo "  - Install packages from packages.txt"
        echo "  - Create picture and local application directories"
        echo "  - Link repo-managed dotfiles into ~/.config when needed"
        echo "  - Configure zsh, oh-my-zsh, plugins, and powerlevel10k"
        echo "  - Enable NetworkManager, bluetooth, pipewire, pipewire-pulse, and wireplumber"
        echo "  - Enable the ly display manager"
        echo "  - Install Librewolf extension policy (auto-installs uBO, Bitwarden, Dark Reader, etc.)"
    fi
    echo ""
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
}

phase_paru() {
    print_phase "Phase 2: AUR Helper (paru)"

    print_info "Ensuring base-devel and git are installed..."
    sudo pacman -S --needed --noconfirm base-devel git

    if command -v paru >/dev/null 2>&1; then
        print_status "paru already installed ($(paru --version | head -n 1))"
        return
    fi

    local tmp
    tmp="$(mktemp -d)"

    print_info "Cloning paru into $tmp..."
    git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp"

    print_status "paru installed"
}

read_packages() {
    # Reads packages.txt into the global $pkgs array.
    # In headless mode, stops at the GUI marker line.
    pkgs=()
    local line
    local in_gui=0
    while IFS= read -r line; do
        if [[ "$line" =~ $GUI_MARKER_REGEX ]]; then
            in_gui=1
            continue
        fi
        if [ "$in_gui" -eq 1 ] && [ "$HEADLESS" -eq 1 ]; then
            continue
        fi
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [ -n "$line" ] || continue
        pkgs+=("$line")
    done < "$SCRIPT_DIR/packages.txt"
}

phase_packages() {
    print_phase "Phase 3: Packages"

    local pkgs
    read_packages

    if [ "${#pkgs[@]}" -eq 0 ]; then
        print_info "No packages listed in packages.txt"
        return
    fi

    local failed=()
    print_info "Installing ${#pkgs[@]} packages via paru; already-installed packages are skipped..."
    for pkg in "${pkgs[@]}"; do
        paru -S --needed --noconfirm "$pkg" || {
            print_error "Failed to install: $pkg (skipping)"
            failed+=("$pkg")
        }
    done

    if [ "${#failed[@]}" -gt 0 ]; then
        echo ""
        print_info "The following packages failed to install:"
        for pkg in "${failed[@]}"; do
            echo "  - $pkg"
        done
        echo ""
        print_info "You may need to install these manually (e.g. via cargo, pip, or from source)"
    else
        print_status "All packages installed"
    fi
}

phase_directories() {
    print_phase "Phase 4: Directories"

    local dirs
    if [ "$HEADLESS" -eq 1 ]; then
        dirs=("$HOME/.local/state")
    else
        dirs=(
            "$HOME/Pictures/Screenshots"
            "$HOME/Pictures/Wallpapers/generated"
            "$HOME/.local/share/applications"
            "$HOME/.local/state"
        )
    fi

    local dir
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_status "Already exists: $dir"
        else
            mkdir -p "$dir"
            print_status "Created: $dir"
        fi
    done
}

phase_dotfiles() {
    print_phase "Phase 5: Dotfiles"

    local config_dirs
    local config_files
    if [ "$HEADLESS" -eq 1 ]; then
        config_dirs=(zsh yazi git tmux nvim)
        config_files=()
    else
        config_dirs=(hypr kitty theme wallpapers gtk-3.0 gtk-4.0 zsh noctalia yazi git tmux nvim)
        config_files=(pavucontrol.ini QtProject.conf)
    fi
    local backup_dir="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    local backed_up=false

    mkdir -p "$HOME/.config"

    backup_and_link() {
        local src="$1"
        local dst="$2"
        local name
        local resolved_src
        local resolved_dst
        name="$(basename "$dst")"

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
        if [ -d "$SCRIPT_DIR/$dir" ]; then
            backup_and_link "$SCRIPT_DIR/$dir" "$HOME/.config/$dir"
        fi
    done

    local file
    for file in "${config_files[@]}"; do
        if [ -f "$SCRIPT_DIR/$file" ]; then
            backup_and_link "$SCRIPT_DIR/$file" "$HOME/.config/$file"
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
    print_phase "Phase 6: Shell"

    if [ "${SHELL:-}" = "/usr/bin/zsh" ]; then
        print_status "zsh already default shell"
    else
        chsh -s /usr/bin/zsh
        print_status "Default shell set to zsh; it takes effect on next login"
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
    print_phase "Phase 7: Services"

    enable_system_service() {
        local svc="$1"
        if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            print_status "Already enabled: $svc"
        else
            sudo systemctl enable "$svc"
            print_status "Enabled: $svc"
        fi
    }

    enable_user_service() {
        local svc="$1"
        if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -z "${XDG_RUNTIME_DIR:-}" ]; then
            print_info "No user session bus; skipping user service: $svc (will auto-start after reboot)"
            return
        fi
        if systemctl --user is-enabled --quiet "$svc" 2>/dev/null; then
            print_status "Already enabled for user: $svc"
        else
            systemctl --user enable "$svc"
            print_status "Enabled for user: $svc"
        fi
    }

    enable_system_service NetworkManager
    enable_system_service avahi-daemon

    if [ "$HEADLESS" -eq 1 ]; then
        enable_system_service sshd
    else
        enable_system_service bluetooth
        enable_user_service pipewire
        enable_user_service pipewire-pulse
        enable_user_service wireplumber
    fi
}

phase_session() {
    if [ "$HEADLESS" -eq 1 ]; then
        print_phase "Phase 8: Session (multi-user.target, no DM)"

        local dm
        for dm in gdm sddm lightdm ly ly@tty1; do
            if systemctl is-enabled --quiet "${dm}.service" 2>/dev/null; then
                print_info "Disabling display manager: ${dm}.service"
                sudo systemctl disable "${dm}.service"
            fi
        done

        local current
        current="$(systemctl get-default)"
        if [ "$current" = "multi-user.target" ]; then
            print_status "Default target already multi-user.target"
        else
            sudo systemctl set-default multi-user.target
            print_status "Default target set to multi-user.target (was $current)"
        fi
        return
    fi

    print_phase "Phase 8: Display Manager (ly)"

    local ly_unit=""
    local dm
    for dm in gdm sddm lightdm; do
        if systemctl is-enabled --quiet "$dm" 2>/dev/null; then
            print_info "Disabling conflicting display manager: $dm"
            sudo systemctl disable "$dm"
        fi
    done

    if [[ -f /usr/lib/systemd/system/ly@.service ]]; then
        ly_unit="ly@tty1.service"
    else
        ly_unit="ly.service"
    fi

    if systemctl is-enabled --quiet "$ly_unit" 2>/dev/null; then
        print_status "$ly_unit already enabled"
    else
        sudo systemctl enable "$ly_unit"
        print_status "Enabled: $ly_unit"
    fi
}

phase_state() {
    mkdir -p "$(dirname "$STATE_FILE")"
    if [ "$HEADLESS" -eq 1 ]; then
        echo "headless" > "$STATE_FILE"
    else
        echo "full" > "$STATE_FILE"
    fi
}

phase_browser_policies() {
    if [ "$HEADLESS" -eq 1 ]; then
        return
    fi

    print_phase "Phase 9: Browser Policies"

    local src="$SCRIPT_DIR/librewolf/policies.json"
    local dst="/etc/librewolf/policies/policies.json"

    if [ ! -f "$src" ]; then
        print_info "No librewolf/policies.json in repo — skipping"
        return
    fi

    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        print_status "Librewolf policies already up to date"
        return
    fi

    print_info "Installing Librewolf policies to $dst (requires sudo)..."
    sudo install -Dm644 "$src" "$dst"
    print_status "Librewolf policies installed; extensions will appear on next launch"
}

phase_reminders() {
    print_phase "Done"

    echo ""
    if [ "$HEADLESS" -eq 1 ]; then
        echo -e "${GREEN}Headless install complete.${NC} Follow-ups:"
        echo ""
        echo -e "${BOLD}1. Configure your prompt${NC}"
        echo "   Open a new shell and run: p10k configure"
        echo ""
        echo -e "${BOLD}2. Verify sshd is reachable${NC}"
        echo "   systemctl status sshd"
        echo ""
        echo -e "${BOLD}3. Reboot (or 'systemctl isolate multi-user.target') to drop the graphical session${NC}"
    else
        echo -e "${GREEN}Installation complete.${NC} Reboot, then complete these manual steps:"
        echo ""
        echo -e "${BOLD}1. Configure your prompt${NC}"
        echo "   Open a new terminal and run: p10k configure"
        echo ""
        echo -e "${BOLD}2. Sync private files (wallpapers, ssh hosts)${NC}"
        echo "   bash $SCRIPT_DIR/sync-private.sh user@your-main-host"
        echo ""
        echo -e "${BOLD}3. Reboot and select Hyprland from ly${NC}"
    fi
    echo ""
}

phase_preflight
phase_paru
phase_packages
phase_directories
phase_dotfiles
phase_shell
phase_services
phase_session
phase_state
phase_browser_policies
phase_reminders
