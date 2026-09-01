#!/bin/bash
# One-time (and after-every-upgrade) setup for yabai's scripting addition.
# Usage: bash scripts/setup-yabai.sh
#
# yabai needs a scripting addition injected into Dock.app for spaces, displays
# and window borders. Loading it needs root, so a sudoers rule pins the exact
# binary hash — which means this must be re-run after every yabai upgrade and
# after macOS updates that reset SIP.
#
# Prerequisite: SIP partially disabled with
#   csrutil enable --without fs --without debug --without nvram
# plus `sudo nvram boot-args=-arm64e_preview_abi` on Apple Silicon.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

for arg in "$@"; do
    case "$arg" in
        --help|-h) sed -n '2,13p' "$0" | sed -E 's/^# ?//'; exit 0 ;;
    esac
done

if [ "$(uname -s)" != "Darwin" ]; then
    print_error "macOS only"
    exit 1
fi

# ---------- 1. Prerequisites ----------

for bin in yabai skhd jq; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        print_error "$bin not found — run 'brew bundle --file=macos/Brewfile' first"
        exit 1
    fi
done

sip="$(csrutil status 2>/dev/null || true)"
missing=""
for prot in "Filesystem Protections" "Debugging Restrictions" "NVRAM Protections"; do
    if ! echo "$sip" | grep -q "$prot: disabled"; then
        missing="$missing\n    - $prot"
    fi
done
if [ -n "$missing" ]; then
    print_error "SIP is not partially disabled. Still enabled:"
    echo -e "$missing"
    print_info "Reboot to Recovery (hold the power button) and run:"
    print_info "  csrutil enable --without fs --without debug --without nvram"
    exit 1
fi
print_status "SIP: fs, debug and nvram protections are disabled"

if [ "$(uname -m)" = "arm64" ] && ! nvram boot-args 2>/dev/null | grep -q arm64e_preview_abi; then
    print_error "boot-args is missing -arm64e_preview_abi (required on Apple Silicon)"
    print_info "  sudo nvram boot-args=-arm64e_preview_abi   # then reboot"
    exit 1
fi

# ---------- 2. AeroSpace conflict ----------

if pgrep -qx AeroSpace 2>/dev/null || pgrep -qf 'AeroSpace.app' 2>/dev/null; then
    print_error "AeroSpace is running — it and yabai both drive the Accessibility"
    print_error "API and will fight over every window."
    print_info "Quit AeroSpace and remove it from Login Items, then re-run."
    exit 1
fi
print_status "AeroSpace is not running"

# ---------- 3. Sudoers rule ----------

YABAI_BIN="$(command -v yabai)"

# Written before loading the addition, so the load below is already passwordless
# and this doubles as a check that the rule works.
#
# The hash pins this rule to the exact binary, so a yabai upgrade invalidates it
# by design — that is why this script is re-run after upgrades.
hash="$(shasum -a 256 "$YABAI_BIN" | cut -d ' ' -f 1)"
rule="$(whoami) ALL=(root) NOPASSWD: sha256:$hash $YABAI_BIN --load-sa"

tmp="$(mktemp)"
echo "$rule" > "$tmp"
# Never install an unvalidated sudoers file: a malformed one can break sudo.
if ! sudo visudo -cf "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    print_error "Generated sudoers rule failed validation; nothing was changed"
    exit 1
fi
sudo install -m 0440 -o root -g wheel "$tmp" /private/etc/sudoers.d/yabai
rm -f "$tmp"
print_status "Sudoers rule installed at /private/etc/sudoers.d/yabai"

# ---------- 4. Scripting addition ----------

# yabai v7 merged install into --load-sa; the separate --install-sa of v6 is gone.
print_info "Installing and loading the scripting addition..."
if ! sudo "$YABAI_BIN" --load-sa; then
    print_error "Could not load the scripting addition"
    print_info "Check SIP with 'csrutil status' and yabai's log:"
    print_info "  tail -50 /tmp/yabai_\$USER.err.log"
    exit 1
fi
print_status "Scripting addition installed and loaded"

# ---------- 5. Services ----------

print_info "Starting yabai and skhd..."
yabai --start-service 2>/dev/null || yabai --restart-service
skhd --start-service 2>/dev/null || skhd --reload
print_status "Services started"

# ---------- 6. Spaces ----------

# skhdrc binds alt-1..9 to real macOS Spaces, which (unlike AeroSpace's
# emulated workspaces) have to exist before they can be focused.
sleep 2
count="$(yabai -m query --spaces 2>/dev/null | jq 'length' || echo 0)"
if [ "$count" -lt 9 ]; then
    print_info "Creating spaces ($count of 9 exist)..."
    while [ "$count" -lt 9 ]; do
        yabai -m space --create || break
        count=$((count + 1))
    done
fi
print_status "$(yabai -m query --spaces | jq 'length') spaces available"

# ---------- Done ----------

echo ""
echo -e "${GREEN}yabai setup complete.${NC}"
echo ""
echo -e "${BOLD}Grant Accessibility permission${NC} to both yabai and skhd when macOS asks:"
echo "  System Settings → Privacy & Security → Accessibility"
echo ""
echo -e "${BOLD}Re-run this script${NC} after every yabai upgrade (the sudoers hash pins the binary)"
echo "and after any macOS update that resets SIP."
echo ""
echo "To go back to AeroSpace: yabai --stop-service && skhd --stop-service,"
echo "then re-enable AeroSpace in Login Items."
echo ""
