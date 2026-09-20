#!/bin/bash
# Read-only diagnostics for the dotfiles repo.
# Usage: bash scripts/doctor.sh
#
# Checks:
#   - Repo mode/state files agree with the installed omarchy package
#   - Exactly one display manager is enabled on a graphical host
#   - The Omarchy shell stack (no noctalia-qs; quickshell runs)
#   - Hyprland config loads without errors
#   - Terminal theme includes resolve (kitty)
#   - Tracks files that `omarchy update` may rewrite in place
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
head() { echo -e "\n${BOLD}== $1 ==${NC}"; }

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
DESKTOP_STATE_FILE="$HOME/.local/state/dotfiles-desktop"

errors=0

note_error() { errors=$((errors + 1)); }

# ---------------------------------------------------------------------------
# Stack consistency
# ---------------------------------------------------------------------------

head "Stack consistency"

detected_desktop="none"
if command -v pacman >/dev/null 2>&1; then
    if pacman -Qq omarchy >/dev/null 2>&1; then
        detected_desktop="omarchy"
    elif pacman -Qq noctalia >/dev/null 2>&1; then
        detected_desktop="noctalia"
    fi
fi

state_desktop=""
if [ -r "$DESKTOP_STATE_FILE" ]; then
    state_desktop="$(cat "$DESKTOP_STATE_FILE" 2>/dev/null || true)"
fi

mode_value=""
if [ -r "$STATE_FILE" ]; then
    mode_value="$(cat "$STATE_FILE" 2>/dev/null || true)"
fi

info "Detected (pacman):   ${detected_desktop:-none}"
info "State file:          ${DESKTOP_STATE_FILE} = ${state_desktop:-<missing>}"
info "Mode file:           ${STATE_FILE} = ${mode_value:-<missing>}"

if [ -z "$state_desktop" ]; then
    err "Desktop state file missing; install.sh or update.sh should write it."
    note_error
elif [ "$state_desktop" != "$detected_desktop" ] && [ "$detected_desktop" != "none" ]; then
    err "Desktop state file disagrees with installed packages."
    err "  Expected: $detected_desktop"
    err "  Got:      $state_desktop"
    note_error
else
    ok "Desktop state matches installed packages."
fi

# ---------------------------------------------------------------------------
# Display managers (graphical hosts only)
# ---------------------------------------------------------------------------

head "Display managers"

if ! command -v systemctl >/dev/null 2>&1; then
    info "systemctl unavailable; skipping."
elif [ "$mode_value" = "headless" ]; then
    info "Headless mode; display managers intentionally absent."
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
        err "  Disable the ones that do not match this desktop stack."
        for dm in "${enabled_dms[@]}"; do
            info "  systemctl disable $dm   # currently enabled"
        done
        note_error
    else
        ok "Exactly one display manager enabled: ${enabled_dms[0]}"
    fi

    # Stack-specific sanity checks.
    if [ "$detected_desktop" = "omarchy" ]; then
        if printf '%s\n' "${enabled_dms[@]}" | grep -qx 'sddm.service'; then
            ok "Omarchy host uses sddm."
        else
            err "Omarchy host is not using sddm."
            note_error
        fi
        if printf '%s\n' "${enabled_dms[@]}" | grep -Eq '^(ly|ly@tty1)\.service$'; then
            err "Omarchy host still has ly enabled; Omarchy requires sddm."
            note_error
        fi
    elif [ "$detected_desktop" = "noctalia" ]; then
        if printf '%s\n' "${enabled_dms[@]}" | grep -Eq '^(ly|ly@tty1)\.service$'; then
            ok "Noctalia host uses ly."
        else
            err "Noctalia host is not using ly."
            note_error
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Omarchy shell stack
# ---------------------------------------------------------------------------

head "Omarchy shell stack"

if ! command -v pacman >/dev/null 2>&1; then
    info "pacman unavailable; skipping."
elif [ "$detected_desktop" = "omarchy" ]; then
    if pacman -Qq noctalia-qs >/dev/null 2>&1; then
        err "noctalia-qs is installed; it conflicts with quickshell and breaks the Omarchy shell."
        err "  sudo pacman -Rdd noctalia-qs && sudo pacman -S quickshell"
        note_error
    else
        ok "noctalia-qs is not installed."
    fi

    if ! pacman -Qq quickshell >/dev/null 2>&1; then
        err "upstream quickshell is missing; Omarchy shell cannot run."
        err "  sudo pacman -S quickshell"
        note_error
    elif command -v quickshell >/dev/null 2>&1 && ! quickshell --version >/dev/null 2>&1; then
        err "quickshell is installed but will not run (likely Qt mismatch):"
        quickshell --version 2>&1 | head -2 | sed 's/^/    /'
        note_error
    else
        ok "quickshell installed and runnable."
    fi
else
    info "Not an Omarchy host; skipping."
fi

# ---------------------------------------------------------------------------
# Hyprland config
# ---------------------------------------------------------------------------

head "Hyprland config"

if ! command -v hyprctl >/dev/null 2>&1; then
    info "hyprctl unavailable; skipping live checks."
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
if [ -r "$entry" ]; then
    ok "Hyprland entry point exists: $entry"
else
    err "Hyprland entry point missing: $entry"
    note_error
fi

# ---------------------------------------------------------------------------
# Terminal theme includes
# ---------------------------------------------------------------------------

head "Terminal theme includes"

omarchy_theme_dir="$HOME/.local/state/omarchy/current/theme"
omarchy_present=0
[ -d "$omarchy_theme_dir" ] && omarchy_present=1

kitty_conf="$HOME/.config/kitty/kitty.conf"
if [ -r "$kitty_conf" ]; then
    ok "kitty.conf exists."
    if grep -qE '^include[[:space:]]+themes/noctalia\.conf' "$kitty_conf"; then
        noctalia_kitty="$HOME/.config/kitty/themes/noctalia.conf"
        if [ -r "$noctalia_kitty" ]; then
            ok "  Noctalia kitty theme resolves."
        else
            err "  Noctalia kitty include missing file: $noctalia_kitty"
            note_error
        fi
    fi
    if grep -qE '^include[[:space:]]+~/.local/state/omarchy/current/theme/kitty\.conf' "$kitty_conf"; then
        if [ "$omarchy_present" = 1 ] && [ -r "$omarchy_theme_dir/kitty.conf" ]; then
            ok "  Omarchy kitty theme resolves."
        else
            info "  Omarchy kitty include set, but no rendered theme yet (run omarchy theme set)."
        fi
    fi
else
    err "kitty.conf missing: $kitty_conf"
    note_error
fi

# ---------------------------------------------------------------------------
# Post-update drift tracking
# ---------------------------------------------------------------------------

head "Post-update drift"

drift_files=(
    "$HOME/.config/kitty/kitty.conf"
    "$HOME/.config/alacritty/alacritty.toml"
)
for f in "${drift_files[@]}"; do
    if [ -e "$f" ]; then
        # Report when the file was modified after the most recent commit that
        # touched its parent directory in this repo. Best-effort only.
        rel="${f#$REPO_DIR/}"
        if [ "${rel:0:1}" = "/" ] || [ "$f" = "$HOME/$rel" ]; then
            info "Tracked terminal config present: $f"
            info "  omarchy helpers may rewrite it in place; check git status."
        fi
    fi
done

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

head "Summary"

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
