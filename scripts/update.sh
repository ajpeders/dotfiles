#!/bin/bash
# Cross-platform dotfiles update script.
# Usage: bash scripts/update.sh [--headless]
# Run from within the dotfiles repo. Pulls latest changes and relinks configs.
#
# - If there is a merge conflict, aborts cleanly (no stashing, no auto-resolve).
# - If the pull is clean, relinks all dotfiles and reloads the WM.
#
# Flags:
#   --headless   Skip GUI packages and desktop dotfiles (Linux only)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error()  { echo -e "${RED}[✗]${NC} $1"; }
print_info()   { echo -e "${YELLOW}[i]${NC} $1"; }
print_phase()  { echo -e "\n${BOLD}== $1 ==${NC}"; }

HEADLESS=0
for arg in "$@"; do
    case "$arg" in
        --headless) HEADLESS=1 ;;
        --help|-h)
            awk 'NR>1 { if (/^#/) { sub(/^# ?/, ""); print } else { exit } }' "$0"
            exit 0
            ;;
        *) print_error "Unknown argument: $arg (try --help)" ; exit 1 ;;
    esac
done

# ── Platform detection ──────────────────────────────────────────────

if [[ "$(uname)" == "Darwin" ]]; then
    PLATFORM="macos"
else
    PLATFORM="linux"
fi

# ── Git pull (abort on conflict) ────────────────────────────────────

print_phase "Phase 1: Pull Latest Changes ($PLATFORM)"

cd "$REPO_DIR"

# Check for uncommitted changes — stash, pull, then restore.
STASHED=false
if ! git diff --quiet || ! git diff --cached --quiet; then
    print_info "Uncommitted changes present:"
    git status --short
    read -rp "Pull anyway? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        git stash push -m "dotfiles-update: auto-stash"
        STASHED=true
        print_info "Stashed — pulling"
    else
        echo "Aborted."
        exit 0
    fi
fi

# Pull — abort immediately on any conflict.
if ! git pull --rebase origin "$(git branch --show-current)"; then
    # If we stashed, restore it so the user can work with their changes.
    if "$STASHED"; then
        git stash pop
    fi
    print_error "Merge conflict — aborting. Resolve with:"
    echo "  git rebase --continue   (after resolving)"
    echo "  git rebase --abort      (to restore pre-pull state)"
    exit 1
fi

# Restore stashed changes.
if "$STASHED"; then
    if ! git stash pop; then
        print_error "Stash conflict — please resolve manually:"
        echo "  git status"
        echo "  git stash drop"
        exit 1
    fi
    print_info "Restored stashed changes"
fi

# Show what was pulled.
BEFORE="$(git rev-parse HEAD~1 2>/dev/null || true)"
AFTER="$(git rev-parse HEAD)"
if [ "$BEFORE" = "$AFTER" ]; then
    print_status "Already up to date"
else
    print_status "Updated:"
    git log --oneline "${BEFORE}..${AFTER}" | sed 's/^/  /'
fi

# ── Dotfile linking ─────────────────────────────────────────────────

link_dotfile() {
    local src="$1" dst="$2" name
    name="$(basename "$dst")"

    # Already linked correctly?
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        print_status "Already linked: $name"
        return
    fi

    # Back up anything in the way.
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        local backup="${dst}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$dst" "$backup"
        print_info "Backed up existing $name to $backup"
    fi

    ln -sfn "$src" "$dst"
    print_status "Linked: $name"
}

print_phase "Phase 2: Relink Dotfiles"

mkdir -p "$HOME/.config" "$HOME/.local/bin"

case "$PLATFORM" in
    linux)
        # Source shared helpers for the full list of dirs.
        source "$SCRIPT_DIR/lib-dotfiles.sh"

        if [ "$HEADLESS" -eq 1 ]; then
            dotfiles_link_configs "${DOTFILES_CLI_DIRS[@]}"
        else
            dotfiles_link_configs "${DOTFILES_CLI_DIRS[@]}" "${DOTFILES_DESKTOP_DIRS[@]}"
        fi
        ;;

    macos)
        # macOS-only configs
        link_dotfile "$SCRIPT_DIR/aerospace"          "$HOME/.config/aerospace"
        link_dotfile "$SCRIPT_DIR/com.alex.mount.share.plist" "$HOME/Library/LaunchAgents/com.alex.mount.share.plist"
        link_dotfile "$SCRIPT_DIR/com.alex.tailscale.plist"    "$HOME/Library/LaunchAgents/com.alex.tailscale.plist"

        # Cross-platform configs
        link_dotfile "$REPO_DIR/kitty"  "$HOME/.config/kitty"
        link_dotfile "$REPO_DIR/yazi"   "$HOME/.config/yazi"
        link_dotfile "$REPO_DIR/zsh"    "$HOME/.config/zsh"
        link_dotfile "$REPO_DIR/tmux"   "$HOME/.config/tmux"
        link_dotfile "$REPO_DIR/opencode" "$HOME/.config/opencode"
        link_dotfile "$REPO_DIR/git"    "$HOME/.config/git"
        link_dotfile "$REPO_DIR/nvim"   "$HOME/.config/nvim"

        # Launchers
        link_dotfile "$REPO_DIR/scripts/opencode-local"   "$HOME/.local/bin/opencode-local"
        link_dotfile "$REPO_DIR/scripts/opencode-cloud"   "$HOME/.local/bin/opencode-cloud"
        link_dotfile "$REPO_DIR/scripts/hq"               "$HOME/.local/bin/hq"
        link_dotfile "$REPO_DIR/scripts/opencode-hybrid"  "$HOME/.local/bin/opencode-hybrid"

        # ZDOTDIR
        if [ ! -f "$HOME/.zshenv" ]; then
            printf 'export ZDOTDIR="$HOME/.config/zsh"\n' > "$HOME/.zshenv"
            print_status "Created ~/.zshenv with ZDOTDIR"
        elif grep -q 'ZDOTDIR=.*\.config/zsh' "$HOME/.zshenv"; then
            print_status "~/.zshenv already configures ZDOTDIR"
        else
            printf '\nexport ZDOTDIR="$HOME/.config/zsh"\n' >> "$HOME/.zshenv"
            print_status "Added ZDOTDIR to ~/.zshenv"
        fi
        ;;
esac

print_status "Dotfiles in sync"

# ── Environment checks ──────────────────────────────────────────────

print_phase "Phase 3: Environment Checks"

# Load the user's shell config so env vars like EDITOR are available.
# Rather than sourcing (which pulls in OMZ, plugins, etc.), extract
# EDITOR from the user's config files.
if [ -z "${EDITOR:-}" ]; then
    for _cfg in "$ZDOTDIR/.zshenv" "$HOME/.config/zsh/.zshenv" \
                 "$ZDOTDIR/.zshrc" "$HOME/.config/zsh/.zshrc" \
                 "$HOME/.zshenv" "$HOME/.zshrc" \
                 "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        if [ -r "$_cfg" ]; then
            _editor="$(grep -m1 '^export EDITOR=' "$_cfg" | sed 's/^export EDITOR=//')"
            if [ -n "$_editor" ]; then
                export EDITOR="$_editor"
                break
            fi
        fi
    done
    unset _cfg _editor
fi

if [ -z "${EDITOR:-}" ]; then
    print_error "\$EDITOR is not set — OpenCode's external editor (Ctrl+X E) won't work"
    print_info "Add 'export EDITOR=nvim' to your shell config (~/.zshrc, ~/.zshenv, etc.)"
else
    if command -v "$EDITOR" >/dev/null 2>&1; then
        print_status "\$EDITOR=$EDITOR is set and available"
    else
        print_error "\$EDITOR=$EDITOR is set but binary not found"
        print_info "Install $EDITOR or update \$EDITOR in your shell config"
    fi
fi

# ── Platform-specific post-steps ────────────────────────────────────

case "$PLATFORM" in
    linux)
        # Browser policies (Linux only)
        if [ "$HEADLESS" -ne 1 ] && command -v python3 >/dev/null 2>&1; then
            print_phase "Phase 4: Browser Policies"
            dotfiles_librewolf_policies
        fi

        # Live reload (Linux only)
        if [ "$HEADLESS" -ne 1 ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            print_phase "Phase 5: Live Reload (Hyprland)"
            if command -v hyprctl >/dev/null 2>&1; then
                if hyprctl reload >/dev/null 2>&1; then
                    print_status "Hyprland reloaded"
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
        else
            print_info "No Hyprland session detected — changes apply after next login"
        fi
        ;;

    macos)
        # Reload AeroSpace (macOS only)
        if command -v aerospace >/dev/null 2>&1; then
            print_phase "Phase 4: Reload AeroSpace"
            if aerospace reload-config >/dev/null 2>&1; then
                print_status "AeroSpace config reloaded"
            else
                print_info "AeroSpace not running — config applies on next launch"
            fi
        fi
        ;;
esac

echo ""
print_status "Update complete."
