#!/bin/bash
# Arch Linux dotfiles update script.
# Usage: bash scripts/update.sh [--headless | --full] [--omarchy | --no-omarchy]
# Run from within the dotfiles repo. Pulls latest changes and syncs everything.
#
# If no flag is given, mode is read from ~/.local/state/dotfiles-mode
# (written by scripts/install.sh); falls back to full-desktop mode if absent.
#
# The desktop stack is detected from the installed omarchy package, falling
# back to ~/.local/state/dotfiles-desktop. Override with --omarchy /
# --no-omarchy. This script never installs Omarchy; use
# `scripts/install.sh --install-omarchy` for that.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-dotfiles.sh
source "$SCRIPT_DIR/lib-dotfiles.sh"
trap dotfiles_release_lock EXIT
dotfiles_acquire_lock

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error()  { echo -e "${RED}[✗]${NC} $1"; }
print_info()   { echo -e "${YELLOW}[i]${NC} $1"; }
print_phase()  { echo -e "\n${BOLD}== $1 ==${NC}"; }

# The repo root is one level up: this script lives in <repo>/scripts/.
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GUI_MARKER_REGEX='^#[[:space:]]*===[[:space:]]*GUI'
NOCTALIA_MARKER_REGEX='^#[[:space:]]*===[[:space:]]*NOCTALIA'
OMARCHY_MARKER_REGEX='^#[[:space:]]*===[[:space:]]*OMARCHY'
STATE_FILE="$HOME/.local/state/dotfiles-mode"
DESKTOP_STATE_FILE="$HOME/.local/state/dotfiles-desktop"

HEADLESS=""
OMARCHY=-1   # -1 = auto-detect, 0 = Noctalia stack, 1 = Omarchy stack
for arg in "$@"; do
    case "$arg" in
        --headless) HEADLESS=1 ;;
        --full)     HEADLESS=0 ;;
        --omarchy)     OMARCHY=1 ;;
        --no-omarchy)  OMARCHY=0 ;;
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

if [ -z "$HEADLESS" ]; then
    if [ -r "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "headless" ]; then
        HEADLESS=1
    else
        HEADLESS=0
    fi
fi

# Single source of truth for desktop detection lives in lib-dotfiles.sh.
# dotfiles_detect_desktop honors explicit --omarchy/--no-omarchy overrides
# first, then the omarchy pacman package, then dotfiles-desktop state file.
OMARCHY=-1 dotfiles_detect_desktop >/dev/null

desktop_label() {
    if [ "$OMARCHY" -eq 1 ]; then echo "Omarchy"; else echo "Noctalia"; fi
}

if [ "$HEADLESS" -eq 1 ]; then
    print_info "Mode: HEADLESS (GUI packages and desktop dotfiles will be skipped)"
else
    print_info "Mode: FULL DESKTOP / $(desktop_label)"
fi

aur_helper=""
detect_aur_helper() {
    if command -v paru >/dev/null 2>&1 && paru --version >/dev/null 2>&1; then
        aur_helper="paru"
        return 0
    fi
    return 1
}

# Re-create ~/.local/state/dotfiles-desktop if a prior install.sh run was
# interrupted before phase_state could write it. Idempotent: the marker file
# marks completion, so this only runs once per machine.
phase_migrations() {
    print_phase "Phase 0: Migrations"

    # Re-create ~/.local/state/dotfiles-desktop if a prior install.sh run was
    # interrupted before phase_state could write it. Idempotent: the marker
    # file marks completion, so this only runs once per machine.
    if [ ! -r "$HOME/.local/state/dotfiles-desktop" ]; then
        local detected="noctalia"
        if command -v pacman >/dev/null 2>&1 && pacman -Qq omarchy >/dev/null 2>&1; then
            detected="omarchy"
        fi
        dotfiles_run_migration ensure-dotfiles-desktop \
            bash -c "echo '$detected' > '$HOME/.local/state/dotfiles-desktop'"
    fi
}

phase_pull() {
    print_phase "Phase 1: Pull Latest Changes"

    cd "$REPO_DIR"

    local stashed=false
    if ! git diff --quiet || ! git diff --cached --quiet; then
        print_info "Uncommitted changes detected:"
        git status --short
        read -rp "Continue anyway? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
        print_info "Temporarily stashing local changes before pull..."
        git stash push --include-untracked -m "dotfiles update autostash $(date +%Y%m%d_%H%M%S)" >/dev/null
        stashed=true
    fi

    local before
    before="$(git rev-parse HEAD)"
    if ! git -c pull.rebase=false pull --ff-only; then
        if [ "$stashed" = true ]; then
            print_info "Restoring stashed local changes..."
            git stash pop || print_error "Stash pop had conflicts; resolve them manually"
        fi
        return 1
    fi
    local after
    after="$(git rev-parse HEAD)"

    if [ "$before" = "$after" ]; then
        print_status "Already up to date"
    else
        print_status "Updated $(git log --oneline "$before..$after" | wc -l) commit(s):"
        git log --oneline "$before..$after" | sed 's/^/  /'
    fi

    if [ "$stashed" = true ]; then
        print_info "Restoring stashed local changes..."
        if git stash pop; then
            print_status "Local changes restored"
        else
            print_error "Stash pop had conflicts; resolve them before continuing"
            return 1
        fi
    fi
}

phase_packages() {
    print_phase "Phase 2: Package Sync"

    if [ ! -f "$REPO_DIR/packages.txt" ]; then
        print_error "packages.txt not found"
        return 1
    fi

    local pkgs=()
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

    # Apple Silicon (Asahi) extras, kept out of packages.txt so x86 never
    # tries to build them from the AUR. Mirrors install.sh.
    if [ "$(uname -m)" = "aarch64" ] && [ -f "$REPO_DIR/packages-asahi.txt" ]; then
        while IFS= read -r line; do
            line="${line%%#*}"
            line="${line//[[:space:]]/}"
            [ -n "$line" ] || continue
            pkgs+=("$line")
        done < "$REPO_DIR/packages-asahi.txt"
    fi

    if [ "${#pkgs[@]}" -eq 0 ]; then
        print_info "No packages in packages.txt"
        return
    fi

    detect_aur_helper || {
        print_error "No working paru found. Run install.sh once to rebuild paru, then rerun update.sh."
        return 1
    }

    print_info "Syncing ${#pkgs[@]} packages with $aur_helper (new packages will be installed)..."
    if "$aur_helper" -S --needed --noconfirm "${pkgs[@]}"; then
        print_status "Packages up to date"
    else
        print_error "Package sync failed"
        return 1
    fi
}

phase_dotfiles() {
    print_phase "Phase 3: Dotfile Sync"

    local config_dirs
    if [ "$HEADLESS" -eq 1 ]; then
        config_dirs=(zsh yazi git tmux nvim opencode)
    else
        config_dirs=(hypr kitty wallpapers gtk-3.0 gtk-4.0 zsh yazi git tmux nvim opencode)
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
        [ -d "$REPO_DIR/$dir" ] && backup_and_link "$REPO_DIR/$dir" "$HOME/.config/$dir"
    done

    mkdir -p "$HOME/.local/bin"
    backup_and_link "$REPO_DIR/scripts/opencode-local" "$HOME/.local/bin/opencode-local"
    backup_and_link "$REPO_DIR/scripts/opencode-cloud" "$HOME/.local/bin/opencode-cloud"

    if [ "$HEADLESS" -ne 1 ] && [ "$OMARCHY" -eq 1 ]; then
        mkdir -p "$HOME/.config/systemd/user"
        backup_and_link "$REPO_DIR/systemd/user/omarchy-wallpaper-colors.service" \
            "$HOME/.config/systemd/user/omarchy-wallpaper-colors.service"
        backup_and_link "$REPO_DIR/systemd/user/omarchy-wallpaper-colors.path" \
            "$HOME/.config/systemd/user/omarchy-wallpaper-colors.path"
    fi

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

phase_browser_policies() {
    if [ "$HEADLESS" -eq 1 ]; then
        return
    fi

    print_phase "Phase 4: Browser Policies"

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

    print_info "Updating Librewolf policies at $dst (requires sudo)..."
    sudo install -Dm644 "$src" "$dst"
    print_status "Librewolf policies updated; restart Librewolf to pick up changes"
}

phase_reload() {
    print_phase "Phase 5: Live Reload"

    if [ "$HEADLESS" -eq 1 ]; then
        print_info "Headless mode — no graphical components to reload"
        return
    fi

    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        print_info "Not inside a Hyprland session — skipping live reload"
        print_info "Changes will take effect after next login"
        return
    fi

    if [ "$OMARCHY" -eq 1 ]; then
        systemctl --user daemon-reload
        systemctl --user enable --now omarchy-wallpaper-colors.path
    fi

    # Hyprland
    if command -v hyprctl >/dev/null 2>&1; then
        if hyprctl reload >/dev/null 2>&1; then
            print_status "Hyprland reloaded"
            # A reload succeeds even when the config has errors in it, so ask.
            local cfg_errors
            cfg_errors="$(hyprctl configerrors 2>/dev/null || true)"
            if [ -n "${cfg_errors//[[:space:]]/}" ]; then
                print_error "Hyprland reported config errors:"
                echo "$cfg_errors"
            else
                print_status "Hyprland config is clean"
            fi
        else
            print_error "hyprctl reload failed (non-fatal)"
        fi
    fi

    # Desktop shell
    if [ "$OMARCHY" -eq 1 ]; then
        if command -v omarchy >/dev/null 2>&1; then
            omarchy restart shell >/dev/null 2>&1 && print_status "Omarchy shell restarted" \
                || print_error "omarchy restart shell failed (non-fatal)"
        fi
    fi

    print_status "Live reload complete"
}

phase_migrations
phase_pull
phase_packages
phase_dotfiles
phase_browser_policies
phase_reload

echo ""
print_status "Update complete."
