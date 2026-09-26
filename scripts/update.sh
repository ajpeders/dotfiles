#!/bin/bash
# Arch Linux dotfiles update script.
# Usage: bash scripts/update.sh [--headless | --full]
# Run from within the dotfiles repo. Pulls latest changes and syncs everything.
#
# If no flag is given, mode is read from ~/.local/state/dotfiles-mode
# (written by scripts/install.sh); falls back to full-desktop mode if absent.


set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-dotfiles.sh
source "$SCRIPT_DIR/lib-dotfiles.sh"
trap dotfiles_release_lock EXIT
dotfiles_acquire_lock

# The repo root is one level up: this script lives in <repo>/scripts/.
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GUI_MARKER_REGEX='^#[[:space:]]*===[[:space:]]*GUI'
STATE_FILE="$HOME/.local/state/dotfiles-mode"

HEADLESS=""
for arg in "$@"; do
    case "$arg" in
        --headless) HEADLESS=1 ;;
        --full)     HEADLESS=0 ;;
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

if [ "$HEADLESS" -eq 1 ]; then
    print_info "Mode: HEADLESS (GUI packages and desktop dotfiles will be skipped)"
else
    print_info "Mode: FULL DESKTOP"
fi

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
        if [ "$section" != base ] && [ "$HEADLESS" -eq 1 ]; then
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

    if [ "$HEADLESS" -eq 1 ]; then
        dotfiles_link_configs "${DOTFILES_CLI_DIRS[@]}"
    else
        dotfiles_link_configs "${DOTFILES_CLI_DIRS[@]}" "${DOTFILES_DESKTOP_DIRS[@]}"
    fi
    print_status "Dotfiles in sync"
}

phase_browser_policies() {
    if [ "$HEADLESS" -eq 1 ]; then
        return
    fi

    print_phase "Phase 4: Browser Policies"
    dotfiles_librewolf_policies
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

    print_status "Live reload complete"
}

phase_pull
phase_packages
phase_dotfiles
phase_browser_policies
phase_reload

echo ""
print_status "Update complete."
