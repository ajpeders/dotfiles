#!/bin/bash
# Read-only diagnostics for the dotfiles repo.
# Usage: bash scripts/doctor.sh
#
# Checks:
#   - Quickshell is installed and no Omarchy package is left behind
#   - Exactly one display manager (ly) is enabled on a graphical host
#   - Hyprland config loads without errors
#   - Terminal theme includes resolve (kitty)
#   - Browser link handler owns http/https
#   - Repo working tree state
#
# Always exits 0; findings are the output. Pair with --strict to fail on
# any error-level finding.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${YELLOW}[i]${NC} $1"; }
section() { echo -e "\n${BOLD}== $1 ==${NC}"; }

STRICT=0
for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --help|-h)
            awk 'NR>1 { if (/^#/) { sub(/^# ?/, ""); print } else { exit } }' "$0"
            exit 0
            ;;
        *)
            err "Unknown argument: $arg (try --help)"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$HOME/.local/state/dotfiles-mode"

errors=0

note_error() { errors=$((errors + 1)); }

# ---------------------------------------------------------------------------
# Stack consistency
# ---------------------------------------------------------------------------

section "Stack consistency"

mode_value=""
if [ -r "$STATE_FILE" ]; then
    mode_value="$(cat "$STATE_FILE" 2>/dev/null || true)"
fi
info "Mode file: ${STATE_FILE} = ${mode_value:-<missing>}"

if ! command -v pacman >/dev/null 2>&1; then
    info "pacman unavailable; skipping."
elif [ "$mode_value" = "headless" ]; then
    info "Headless mode; no desktop stack expected."
else
    if pacman -Qq quickshell >/dev/null 2>&1; then
        ok "quickshell is installed."
    else
        err "quickshell is not installed; run scripts/install.sh."
        note_error
    fi
    # Leftovers from the retired Omarchy stack (see HOWTO.md).
    leftovers="$(pacman -Qq 2>/dev/null | grep -E '^omarchy' || true)"
    if [ -n "$leftovers" ]; then
        err "Omarchy packages still installed: $(echo "$leftovers" | tr "\n" " ")"
        note_error
    else
        ok "No Omarchy packages installed."
    fi
fi

if [ "$mode_value" = "headless" ]; then
    info "Headless mode; JetShell not required."
elif [ -f "$HOME/.config/jetshell/shell.qml" ]; then
    ok "JetShell checkout found at ~/.config/jetshell."
else
    err "JetShell missing: clone it into ~/.config/jetshell or symlink a checkout there."
    note_error
fi

# ---------------------------------------------------------------------------
# Display managers (graphical hosts only)
# ---------------------------------------------------------------------------

section "Display managers"

if ! command -v systemctl >/dev/null 2>&1; then
    info "systemctl unavailable; skipping."
elif [ "$mode_value" = "headless" ]; then
    enabled_dms=()
    for dm in sddm.service gdm.service lightdm.service ly.service ly@tty1.service; do
        if systemctl is-enabled --quiet "$dm" 2>/dev/null; then
            enabled_dms+=("$dm")
        fi
    done
    if [ ${#enabled_dms[@]} -gt 0 ]; then
        err "Headless mode has enabled display managers: ${enabled_dms[*]}"
        note_error
    else
        ok "No display manager enabled (headless mode)."
    fi
    if [ "$(systemctl get-default 2>/dev/null)" != "multi-user.target" ]; then
        err "Headless mode should default to multi-user.target."
        note_error
    else
        ok "Default target is multi-user.target."
    fi
else
    enabled_dms=()
    for dm in sddm.service gdm.service lightdm.service ly.service ly@tty1.service; do
        if systemctl is-enabled --quiet "$dm" 2>/dev/null; then
            enabled_dms+=("$dm")
        fi
    done

    if [ ${#enabled_dms[@]} -eq 0 ]; then
        err "No graphical display manager enabled."
        note_error
    elif [ ${#enabled_dms[@]} -gt 1 ]; then
        err "Multiple display managers enabled: ${enabled_dms[*]}"
        err "  Keep only ly enabled."
        for dm in "${enabled_dms[@]}"; do
            info "  systemctl disable $dm   # currently enabled"
        done
        note_error
    else
        ok "Exactly one display manager enabled: ${enabled_dms[0]}"
    fi

    if printf '%s\n' "${enabled_dms[@]}" | grep -Eq '^(ly|ly@tty1)\.service$'; then
        ok "ly is the display manager."
    else
        err "ly is not enabled; run scripts/install.sh."
        note_error
    fi
fi

# ---------------------------------------------------------------------------
# Hyprland config
# ---------------------------------------------------------------------------

section "Hyprland config"

if [ "$mode_value" = "headless" ]; then
    info "Headless mode; Hyprland config not required."
elif ! command -v hyprctl >/dev/null 2>&1; then
    info "hyprctl unavailable; skipping live checks."
elif [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    info "Not inside a Hyprland session; skipping live checks."
else
    cfg_errors="$(hyprctl configerrors 2>/dev/null || true)"
    if [ -z "$cfg_errors" ]; then
        ok "hyprctl configerrors: none."
    else
        err "Hyprland reports config errors:"
        printf '%s\n' "$cfg_errors" | sed 's/^/    /'
        note_error
    fi
fi

entry="$HOME/.config/hypr/hyprland.lua"
if [ "$mode_value" != "headless" ] && [ -r "$entry" ]; then
    ok "Hyprland entry point exists: $entry"
elif [ "$mode_value" != "headless" ]; then
    err "Hyprland entry point missing: $entry"
    note_error
fi

# ---------------------------------------------------------------------------
# Terminal theme includes
# ---------------------------------------------------------------------------

section "Terminal theme includes"

kitty_conf="$HOME/.config/kitty/kitty.conf"
if [ "$mode_value" = "headless" ]; then
    info "Headless mode; kitty theme not required."
elif [ -r "$kitty_conf" ]; then
    ok "kitty.conf exists."
    if grep -qE '^include[[:space:]]+themes/quickshell\.conf' "$kitty_conf"; then
        quickshell_kitty="$HOME/.config/kitty/themes/quickshell.conf"
        if [ -r "$quickshell_kitty" ]; then
            ok "  Quickshell kitty theme resolves."
        else
            err "  Quickshell kitty include missing file: $quickshell_kitty"
            note_error
        fi
    fi
else
    err "kitty.conf missing: $kitty_conf"
    note_error
fi

# ---------------------------------------------------------------------------
# Link handler
# ---------------------------------------------------------------------------

section "Link handler"

# kitty and opencode both call xdg-open for clicked links; the MIME default
# decides whether the URL lands in a new window on this workspace or in a tab
# on whatever workspace the browser was last left on.
if [ "$mode_value" = "headless" ]; then
    info "Headless mode; browser link handler not required."
elif ! command -v xdg-mime >/dev/null 2>&1; then
    info "xdg-mime unavailable; skipping."
else
    handler_desktop="$HOME/.local/share/applications/librewolf-new-window.desktop"
    if [ -r "$handler_desktop" ]; then
        ok "librewolf-new-window.desktop installed."
    else
        err "librewolf-new-window.desktop missing: $handler_desktop (run scripts/update.sh)"
        note_error
    fi

    mime_drift=""
    for mime in x-scheme-handler/http x-scheme-handler/https; do
        current_mime="$(xdg-mime query default "$mime" 2>/dev/null || true)"
        if [ "$current_mime" != "librewolf-new-window.desktop" ]; then
            mime_drift="$mime (${current_mime:-<unset>})"
        fi
    done
    if [ -n "$mime_drift" ]; then
        err "Links do not open in a new window on the current workspace: $mime_drift"
        note_error
    else
        ok "http/https links open in a new LibreWolf window."
    fi
fi

# ---------------------------------------------------------------------------
# Working tree
# ---------------------------------------------------------------------------

section "Git identity"

# git/config includes ~/.gitconfig.local instead of carrying a [user] block.
if command -v git >/dev/null 2>&1; then
    if [ -n "$(git -C "$REPO_DIR" config user.email 2>/dev/null)" ]; then
        ok "git user.email set."
    else
        err "git user.email unset; create ~/.gitconfig.local with [user] name/email (README)."
        note_error
    fi
fi

section "Working tree"

if command -v git >/dev/null 2>&1 && [ -d "$REPO_DIR/.git" ]; then
    dirty="$(git -C "$REPO_DIR" status --porcelain 2>/dev/null || true)"
    if [ -n "$dirty" ]; then
        info "Repo has uncommitted changes:"
        printf '%s\n' "$dirty" | sed 's/^/    /'
    else
        ok "Repo working tree clean."
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

section "Summary"

if [ "$errors" -eq 0 ]; then
    ok "No findings."
    exit 0
fi

err "$errors finding(s) reported above."
if [ "$STRICT" -eq 1 ]; then
    err "--strict: exiting non-zero."
    exit 1
fi
info "Re-run with --strict to fail on any finding."
exit 0
