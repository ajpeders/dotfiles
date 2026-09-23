#!/bin/bash
# Arch Linux dotfiles bootstrap script.
# Usage: bash scripts/install.sh [--headless] [--omarchy|--no-omarchy] [--install-omarchy]
# Run from within the cloned dotfiles repo as a non-root user.
# Safe to re-run: each phase checks whether its work is already done.
#
# Modes:
#   (default)    Full Hyprland desktop install.
#   --headless   Skip GUI packages, desktop dotfiles, and the display manager.
#                Sets the system to multi-user.target and enables sshd.
#
# Desktop stack (full mode only) is auto-detected:
#   Omarchy present  -> Omarchy owns Hyprland, the shell and the display
#                       manager; the Noctalia/ly packages and phases are
#                       skipped. Override with --no-omarchy.
#   Omarchy absent   -> the original Noctalia + ly desktop. Force the Omarchy
#                       path on a machine where the package is not installed
#                       yet with --omarchy.
#
#   --install-omarchy  Bootstrap Omarchy itself before applying dotfiles, on a
#                      machine that does not have it yet. Implies --omarchy.
#                      aarch64 only; see phase_omarchy for why.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-dotfiles.sh
source "$SCRIPT_DIR/lib-dotfiles.sh"
trap dotfiles_release_lock EXIT
dotfiles_acquire_lock

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }
print_phase() { echo -e "\n${BOLD}== $1 ==${NC}"; }

# The repo root is one level up: this script lives in <repo>/scripts/.
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GUI_MARKER_REGEX='^#[[:space:]]*===[[:space:]]*GUI'
NOCTALIA_MARKER_REGEX='^#[[:space:]]*===[[:space:]]*NOCTALIA'
OMARCHY_MARKER_REGEX='^#[[:space:]]*===[[:space:]]*OMARCHY'
STATE_FILE="$HOME/.local/state/dotfiles-mode"
DESKTOP_STATE_FILE="$HOME/.local/state/dotfiles-desktop"

# Upstream Omarchy 4 installs from an ISO with no aarch64 build, which cannot
# boot an Apple Silicon Mac. This fork builds the (arch=any) Omarchy packages
# from a checkout and installs them the way the ISO would.
OMARCHY_MAC_REPO="https://github.com/omacom/omarchy-mac.git"
OMARCHY_MAC_BRANCH="quattro"
# Omarchy's own shell integration reads from this path too (default/zsh/rc),
# so it is the checkout location, not a scratch dir.
OMARCHY_MAC_DIR="$HOME/.local/share/omarchy"

HEADLESS=0
OMARCHY=-1       # -1 = auto-detect, 0 = Noctalia stack, 1 = Omarchy stack
INSTALL_OMARCHY=0
for arg in "$@"; do
    case "$arg" in
        --headless) HEADLESS=1 ;;
        --omarchy) OMARCHY=1 ;;
        --no-omarchy) OMARCHY=0 ;;
        # Installing a whole desktop layer must never be a side effect of a
        # routine resync, so it takes an explicit flag.
        --install-omarchy) INSTALL_OMARCHY=1; OMARCHY=1 ;;
        --help|-h)
            # Print the whole leading comment block, so editing the header
            # above cannot silently truncate --help.
            awk 'NR>1 { if (/^#/) { sub(/^# ?/, ""); print } else { exit } }' "$0"
            exit 0
            ;;
        *)
            print_error "Unknown argument: $arg (try --help)"
            exit 1
            ;;
    esac
done

# Omarchy installs itself as a pacman package and owns Hyprland, the shell and
# the display manager. The shared detector in lib-dotfiles.sh is the single
# source of truth; this shim keeps the old name working.
detect_desktop() {
    OMARCHY=-1 dotfiles_detect_desktop >/dev/null
}

desktop_label() {
    if [ "$OMARCHY" -eq 1 ]; then echo "Omarchy"; else echo "Noctalia"; fi
}

mode_label() {
    if [ "$HEADLESS" -eq 1 ]; then
        echo "HEADLESS"
    else
        echo "FULL DESKTOP / $(desktop_label)"
    fi
}

# Omarchy's shell (bar, notifications, OSD, lock screen) is one Quickshell
# process. noctalia-qs declares both Provides: quickshell and Conflicts:
# quickshell, so if it is present pacman considers Omarchy's dependency
# satisfied and never installs the real package. The fork is built against an
# older Qt, so omarchy-shell then dies at startup with a symbol lookup error
# and the desktop comes up with no bar at all -- silently, because Hyprland
# itself is fine. Fail loudly instead.
verify_omarchy_shell_stack() {
    local ok=0

    if pacman -Qq noctalia-qs >/dev/null 2>&1; then
        print_error "noctalia-qs is installed; it conflicts with quickshell and"
        print_error "will break the Omarchy shell. Remove it and install quickshell:"
        print_error "  sudo pacman -Rdd noctalia-qs && sudo pacman -S quickshell"
        ok=1
    fi

    if ! pacman -Qq quickshell >/dev/null 2>&1; then
        print_error "upstream quickshell is not installed; the Omarchy shell cannot run."
        print_error "  sudo pacman -S quickshell"
        ok=1
    elif ! quickshell --version >/dev/null 2>&1; then
        print_error "quickshell is installed but will not run (likely a Qt mismatch):"
        quickshell --version 2>&1 | head -2
        ok=1
    fi

    if [ "$ok" -eq 0 ]; then
        print_status "Omarchy shell stack OK ($(quickshell --version 2>/dev/null | head -1))"
    fi
    return "$ok"
}

# Bootstraps Omarchy itself. Must run before phase_dotfiles: the fork's
# installer ends in seed_user_defaults, which copies Omarchy's stock configs
# into ~/.config and will overwrite tracked files (it replaced kitty.conf and
# tmux.conf here). Applying dotfiles afterwards is what makes ours win.
phase_omarchy() {
    if [ "$HEADLESS" -eq 1 ] || [ "$OMARCHY" -ne 1 ]; then
        return
    fi

    print_phase "Phase 2: Omarchy"

    if pacman -Qq omarchy >/dev/null 2>&1; then
        print_status "Omarchy already installed ($(pacman -Q omarchy | awk '{print $2}'))"
        verify_omarchy_shell_stack || true
        return
    fi

    if [ "$INSTALL_OMARCHY" -ne 1 ]; then
        print_error "Omarchy is not installed, but the Omarchy stack was selected."
        print_error "Re-run with --install-omarchy to bootstrap it, or --no-omarchy"
        print_error "to use the Noctalia desktop instead."
        exit 1
    fi

    local arch
    arch="$(uname -m)"
    if [ "$arch" != "aarch64" ]; then
        print_error "No scripted Omarchy install exists for $arch."
        print_error "Upstream Omarchy 4 installs from its ISO -- see https://omarchy.org"
        print_error "This flag only covers Apple Silicon, where the ISO cannot boot and"
        print_error "$OMARCHY_MAC_REPO builds the packages instead."
        exit 1
    fi

    # The fork's installer refuses to run as root and sudo's where it needs to.
    if [ "$EUID" -eq 0 ]; then
        print_error "Run this as your regular user, not root."
        exit 1
    fi

    if [ -d "$OMARCHY_MAC_DIR/.git" ]; then
        print_info "Updating existing checkout in $OMARCHY_MAC_DIR..."
        git -C "$OMARCHY_MAC_DIR" fetch --quiet origin "$OMARCHY_MAC_BRANCH"
        git -C "$OMARCHY_MAC_DIR" checkout --quiet "$OMARCHY_MAC_BRANCH"
        git -C "$OMARCHY_MAC_DIR" merge --ff-only --quiet "origin/$OMARCHY_MAC_BRANCH"
    else
        if [ -e "$OMARCHY_MAC_DIR" ]; then
            print_error "$OMARCHY_MAC_DIR exists but is not a git checkout; move it aside first."
            exit 1
        fi
        print_info "Cloning $OMARCHY_MAC_REPO ($OMARCHY_MAC_BRANCH)..."
        mkdir -p "$(dirname "$OMARCHY_MAC_DIR")"
        git clone --quiet --branch "$OMARCHY_MAC_BRANCH" "$OMARCHY_MAC_REPO" "$OMARCHY_MAC_DIR"
    fi
    print_status "Checkout at $(git -C "$OMARCHY_MAC_DIR" rev-parse --short HEAD)"

    print_info "Running Omarchy's installer. This adds pacman repos and keys,"
    print_info "builds the Omarchy packages and installs its default package set."
    print_info "It is long, interactive in places, and asks for sudo."
    bash "$OMARCHY_MAC_DIR/install.sh"

    if ! pacman -Qq omarchy >/dev/null 2>&1; then
        print_error "Omarchy's installer finished but the omarchy package is absent."
        exit 1
    fi
    print_status "Omarchy installed ($(pacman -Q omarchy | awk '{print $2}'))"
    verify_omarchy_shell_stack || true
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

    if [ ! -f "$REPO_DIR/packages.txt" ]; then
        print_error "packages.txt not found; run this script from within the dotfiles repo"
        exit 1
    fi
    print_status "Dotfiles repo found at: $REPO_DIR"

    echo ""
    print_info "This script will:"
    echo "  - Install paru if needed"
    if [ "$HEADLESS" -eq 1 ]; then
        echo "  - Install headless packages from packages.txt (GUI packages skipped)"
        echo "  - Link CLI dotfiles into ~/.config (shell, editor, tmux, yazi, git, opencode)"
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

aur_helper=""

detect_aur_helper() {
    if command -v paru >/dev/null 2>&1 && paru --version >/dev/null 2>&1; then
        aur_helper="paru"
        return 0
    fi
    return 1
}

phase_paru() {
    print_phase "Phase 3: AUR Helper (paru)"

    print_info "Ensuring base-devel and git are installed..."
    sudo pacman -S --needed --noconfirm base-devel git

    if detect_aur_helper; then
        print_status "paru already installed ($(paru --version | head -n 1))"
        return
    fi

    if command -v paru >/dev/null 2>&1; then
        print_info "paru is installed but cannot start; rebuilding it against current pacman..."
    fi

    local tmp
    tmp="$(mktemp -d)"

    print_info "Cloning paru into $tmp..."
    git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp"

    print_status "paru installed"
    aur_helper="paru"
}

read_packages() {
    # Reads packages.txt into the global $pkgs array.
    # In headless mode, stops at the GUI marker line.
    pkgs=()
    local line
    local section=base
    while IFS= read -r line; do
        if [[ "$line" =~ $GUI_MARKER_REGEX ]]; then
            section=gui
            continue
        fi
        if [[ "$line" =~ $NOCTALIA_MARKER_REGEX ]]; then
            section=noctalia
            continue
        fi
        if [[ "$line" =~ $OMARCHY_MARKER_REGEX ]]; then
            section=omarchy
            continue
        fi
        # Everything past the GUI marker is desktop-only.
        if [ "$section" != base ] && [ "$HEADLESS" -eq 1 ]; then
            continue
        fi
        if [ "$section" = noctalia ] && [ "$OMARCHY" -eq 1 ]; then
            continue
        fi
        if [ "$section" = omarchy ] && [ "$OMARCHY" -ne 1 ]; then
            continue
        fi
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [ -n "$line" ] || continue
        pkgs+=("$line")
    done < "$REPO_DIR/packages.txt"

    # Apple Silicon (Asahi) extras. Kept out of packages.txt so x86 never
    # tries to build them from the AUR.
    if [ "$(uname -m)" = "aarch64" ] && [ -f "$REPO_DIR/packages-asahi.txt" ]; then
        while IFS= read -r line; do
            line="${line%%#*}"
            line="${line//[[:space:]]/}"
            [ -n "$line" ] || continue
            pkgs+=("$line")
        done < "$REPO_DIR/packages-asahi.txt"
    fi
}

phase_packages() {
    print_phase "Phase 4: Packages"

    local pkgs
    read_packages

    if [ "${#pkgs[@]}" -eq 0 ]; then
        print_info "No packages listed in packages.txt"
        return
    fi

    local failed=()
    detect_aur_helper || {
        print_error "No working paru found"
        return 1
    }

    print_info "Installing ${#pkgs[@]} packages via $aur_helper; already-installed packages are skipped..."
    for pkg in "${pkgs[@]}"; do
        "$aur_helper" -S --needed --noconfirm "$pkg" || {
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
    print_phase "Phase 5: Directories"

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
    print_phase "Phase 6: Dotfiles"

    local config_dirs
    if [ "$HEADLESS" -eq 1 ]; then
        config_dirs=(zsh yazi git tmux nvim opencode)
    else
        config_dirs=(hypr kitty wallpapers gtk-3.0 gtk-4.0 zsh yazi git tmux nvim opencode)
        # Each desktop keeps its own config dir; linking the other one just
        # leaves a dead directory behind.
        if [ "$OMARCHY" -eq 1 ]; then
            config_dirs+=(omarchy)
        else
            config_dirs+=(noctalia)
        fi
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
        if [ -d "$REPO_DIR/$dir" ]; then
            backup_and_link "$REPO_DIR/$dir" "$HOME/.config/$dir"
        fi
    done

    mkdir -p "$HOME/.config/systemd/user"
    backup_and_link "$REPO_DIR/systemd/user/dotfiles-autopull.service" \
        "$HOME/.config/systemd/user/dotfiles-autopull.service"
    backup_and_link "$REPO_DIR/systemd/user/dotfiles-autopull.timer" \
        "$HOME/.config/systemd/user/dotfiles-autopull.timer"

    if [ "$HEADLESS" -ne 1 ] && [ "$OMARCHY" -eq 1 ]; then
        mkdir -p "$HOME/.config/systemd/user"
        backup_and_link "$REPO_DIR/systemd/user/omarchy-wallpaper-colors.service" \
            "$HOME/.config/systemd/user/omarchy-wallpaper-colors.service"
        backup_and_link "$REPO_DIR/systemd/user/omarchy-wallpaper-colors.path" \
            "$HOME/.config/systemd/user/omarchy-wallpaper-colors.path"

        # kitty.conf has a conditional Noctalia include that points nowhere
        # on a host that has never run Noctalia. Comment it out so future
        # kitty reloads stop warning about a missing include.
        if ! pacman -Qq noctalia >/dev/null 2>&1; then
            local kitty_conf="$HOME/.config/kitty/kitty.conf"
            if [ -r "$kitty_conf" ] && grep -qE '^include[[:space:]]+themes/noctalia\.conf[[:space:]]*$' "$kitty_conf"; then
                sed -i 's|^include[[:space:]]\+themes/noctalia\.conf[[:space:]]*$|# include themes/noctalia.conf -- not on a Noctalia host|' "$kitty_conf"
                print_status "Disabled Noctalia include in kitty.conf"
            fi
        fi
    fi

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
    print_phase "Phase 7: Shell"

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

    if [ -d "$zsh_custom/plugins/fzf-tab" ]; then
        print_status "fzf-tab already installed"
    else
        git clone https://github.com/Aloxaf/fzf-tab "$zsh_custom/plugins/fzf-tab"
        print_status "fzf-tab installed"
    fi

    if [ -d "$zsh_custom/themes/powerlevel10k" ]; then
        print_status "powerlevel10k already installed"
    else
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$zsh_custom/themes/powerlevel10k"
        print_status "powerlevel10k installed"
    fi

}

phase_services() {
    print_phase "Phase 8: Services"

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
    # Tailscale: the unit is enough to bring the tunnel up at boot; the node
    # still needs a one-time `sudo tailscale up` to authenticate.
    enable_system_service tailscaled

    # Keep this clone in sync with GitHub main (scripts/autopull.sh).
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}${XDG_RUNTIME_DIR:-}" ]; then
        systemctl --user daemon-reload
    fi
    enable_user_service dotfiles-autopull.timer

    if [ "$HEADLESS" -eq 1 ]; then
        enable_system_service sshd
    else
        enable_system_service bluetooth
        enable_user_service pipewire
        enable_user_service pipewire-pulse
        enable_user_service wireplumber
        if [ "$OMARCHY" -eq 1 ]; then
            systemctl --user daemon-reload
            enable_user_service omarchy-wallpaper-colors.path
        fi
    fi
}

phase_session() {
    if [ "$HEADLESS" -eq 1 ]; then
        print_phase "Phase 9: Session (multi-user.target, no DM)"

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

    if [ "$OMARCHY" -eq 1 ]; then
        print_phase "Phase 9: Display Manager (managed by Omarchy)"

        local dm
        for dm in gdm.service lightdm.service ly.service ly@tty1.service; do
            if systemctl is-enabled --quiet "$dm" 2>/dev/null; then
                print_info "Disabling conflicting display manager: $dm"
                # Do not use --now: this session may have been launched by it.
                sudo systemctl disable "$dm"
            fi
        done

        if systemctl is-enabled --quiet sddm.service 2>/dev/null; then
            print_status "sddm.service already enabled"
        else
            sudo systemctl enable sddm.service
            print_status "Enabled: sddm.service"
        fi
        return
    fi

    print_phase "Phase 9: Display Manager (ly)"

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
        echo "$(desktop_label | tr '[:upper:]' '[:lower:]')" > "$DESKTOP_STATE_FILE"
    fi
}

phase_browser_policies() {
    if [ "$HEADLESS" -eq 1 ]; then
        return
    fi

    print_phase "Phase 10: Browser Policies"

    local src="$REPO_DIR/librewolf/policies.json"
    local dst="/etc/librewolf/policies/policies.json"

    if [ ! -f "$src" ]; then
        print_info "No librewolf/policies.json in repo — skipping"
        return
    fi

    if ! pacman -Qq librewolf-bin librewolf >/dev/null 2>&1; then
        print_info "Librewolf is not installed — skipping policies"
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
        if [ "$OMARCHY" -eq 1 ]; then
            echo -e "${BOLD}3. Reboot${NC}"
            echo "   sddm starts the Omarchy Hyprland session."
            echo "   Check the bar came up with: omarchy restart shell"
        else
            echo -e "${BOLD}3. Reboot and select Hyprland from ly${NC}"
        fi
    fi
    echo ""
}

phase_preflight
detect_desktop
phase_omarchy
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
