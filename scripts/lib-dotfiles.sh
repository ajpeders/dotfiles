#!/bin/bash
# Shared helpers for scripts/install.sh and update.sh.
# Sourced, never run directly.

# Prevent direct execution.
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
    echo "scripts/lib-dotfiles.sh is a library, not a script." >&2
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error()  { echo -e "${RED}[✗]${NC} $1"; }
print_info()   { echo -e "${YELLOW}[i]${NC} $1"; }
print_phase()  { echo -e "\n${BOLD}== $1 ==${NC}"; }

# Config dirs linked into ~/.config; desktop ones on full Arch installs only.
DOTFILES_CLI_DIRS=(zsh yazi git tmux nvim opencode)
DOTFILES_DESKTOP_DIRS=(hypr kitty gtk-3.0 gtk-4.0 jetshell)

DOTFILES_LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}"
DOTFILES_LOCK_PATH="$DOTFILES_LOCK_DIR/dotfiles.lock"

# dotfiles_acquire_lock -- grab a non-blocking flock on DOTFILES_LOCK_PATH.
# Sets DOTFILES_LOCK_FD in the caller; on failure, prints and exits.
dotfiles_acquire_lock() {
    mkdir -p "$DOTFILES_LOCK_DIR" 2>/dev/null || true
    exec {DOTFILES_LOCK_FD}>"$DOTFILES_LOCK_PATH"
    if ! flock -n "$DOTFILES_LOCK_FD"; then
        echo -e "${RED}[✗]${NC} Another dotfiles script is already running." >&2
        echo -e "${RED}[✗]${NC} If that is stale, remove $DOTFILES_LOCK_PATH." >&2
        exit 1
    fi
}

# dotfiles_release_lock -- close the FD set by dotfiles_acquire_lock.
dotfiles_release_lock() {
    if [[ -n "${DOTFILES_LOCK_FD:-}" ]]; then
        flock -u "$DOTFILES_LOCK_FD" 2>/dev/null || true
        exec {DOTFILES_LOCK_FD}>&- 2>/dev/null || true
        unset DOTFILES_LOCK_FD
    fi
}


aur_helper=""
detect_aur_helper() {
    if command -v paru >/dev/null 2>&1 && paru --version >/dev/null 2>&1; then
        aur_helper="paru"
        return 0
    fi
    return 1
}

# _dotfiles_link SRC DST -- symlink, moving anything in the way into the
# caller's $backup_dir (and setting its $backed_up).
_dotfiles_link() {
    local src="$1" dst="$2" name resolved_src resolved_dst
    name="$(basename "$dst")"

    resolved_src="$(readlink -f "$src")"
    resolved_dst="$(readlink -f "$dst" 2>/dev/null || true)"
    if [ "$resolved_src" = "$resolved_dst" ]; then
        print_status "Already in place: $name"
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

# dotfiles_link_configs DIR... -- link each repo dir into ~/.config and the
# launchers into ~/.local/bin, and point ~/.zshenv at ZDOTDIR.
dotfiles_link_configs() {
    local backup_dir="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    local backed_up=false dir launcher

    mkdir -p "$HOME/.config" "$HOME/.local/bin"

    for dir in "$@"; do
        if [ -d "$REPO_DIR/$dir" ]; then
            _dotfiles_link "$REPO_DIR/$dir" "$HOME/.config/$dir"
        fi
    done

    # Derive the launcher list from disk so new scripts/opencode-* (and any
    # future sibling like hq/jetshell) are picked up automatically without
    # touching this loop. Add each launcher to a separate manifest list if it
    # ever needs to be excluded by name; otherwise anything executable under
    # scripts/ that is *not* dotfiles.sh, install.sh, update.sh,
    # uninstall.sh, doctor.sh, sync-private.sh, or setup-llm.sh gets linked.
    local launcher
    for launcher in "$REPO_DIR/scripts"/opencode-* "$REPO_DIR/scripts"/hq "$REPO_DIR/scripts"/jetshell; do
        # The shell leaves the pattern literal when no matches; guard against
        # that so we don't try to link the string "*opencode-*".
        if [ ! -e "$launcher" ]; then
            continue
        fi
        _dotfiles_link "$launcher" "$HOME/.local/bin/$(basename "$launcher")"
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
}

# dotfiles_librewolf_policies -- merge librewolf/policies.json over Librewolf's
# own bundled policies and install the result, if Librewolf is installed and the
# system copy differs.
#
# Librewolf ships its hardening as distribution/policies.json in the install
# dir, but Gecko reads exactly ONE policy file: when /etc/librewolf/policies/
# policies.json exists it is used and the bundled one is never consulted (see
# JSONPoliciesProvider._getLocalConfigurationFile). Writing the repo file there
# verbatim therefore silently dropped DisableTelemetry, DisableAppUpdate,
# DisablePocket, SkipTermsOfUse, SearchEngines and the rest. Merge instead, so
# the repo only adds its extensions on top.
dotfiles_librewolf_policies() {
    local src="$REPO_DIR/librewolf/policies.json"
    local base="/usr/lib/librewolf/distribution/policies.json"
    local dst="/etc/librewolf/policies/policies.json"

    if [ ! -f "$src" ]; then
        print_info "No librewolf/policies.json in repo — skipping"
        return
    fi

    if ! pacman -Qq librewolf >/dev/null 2>&1; then
        print_info "Librewolf is not installed — skipping policies"
        return
    fi

    local merged
    merged="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$merged'" RETURN

    if ! python3 - "$src" "$base" "$merged" <<'PY'
import json, sys

src, base, out = sys.argv[1:4]


def policies(path):
    try:
        with open(path) as fh:
            return json.load(fh).get("policies", {})
    except FileNotFoundError:
        return {}


merged = policies(base)
for name, value in policies(src).items():
    # ExtensionSettings is a map of addon id -> settings. Replacing the whole
    # object would drop Librewolf's "*" default and its blocked search addons;
    # replacing a whole entry would drop per-addon keys the repo omits, such as
    # private_browsing on uBlock Origin. So merge both levels.
    if name == "ExtensionSettings" and isinstance(merged.get(name), dict):
        for addon, settings in value.items():
            current = merged[name].get(addon)
            if isinstance(current, dict) and isinstance(settings, dict):
                merged[name][addon] = {**current, **settings}
            else:
                merged[name][addon] = settings
    else:
        merged[name] = value

with open(out, "w") as fh:
    json.dump({"policies": merged}, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
    then
        print_error "Could not merge Librewolf policies — leaving $dst alone"
        return
    fi

    if [ -f "$dst" ] && cmp -s "$merged" "$dst"; then
        print_status "Librewolf policies already up to date"
        return
    fi

    print_info "Installing Librewolf policies to $dst (requires sudo)..."
    sudo install -Dm644 "$merged" "$dst"
    print_status "Librewolf policies installed; restart Librewolf to apply"
}

# dotfiles_browser_link_handler -- register librewolf/new-window.desktop as the
# default http(s) handler.
#
# kitty (open_url_with default) and opencode both hand a clicked link to
# xdg-open, which resolves the MIME type to a desktop entry. Left alone that is
# LibreWolf's own entry, `librewolf %u`, which opens the URL as a tab in the
# most recently used window — a window sitting on whatever workspace it was last
# left on, which is why links seemed to open on the wrong workspace. Routing the
# same URL through --new-window gets a fresh window, and Hyprland maps new
# windows onto the focused monitor's active workspace.
#
# Writes only to ~/.local/share/applications and the (untracked) mimeapps.list.
dotfiles_browser_link_handler() {
    local src="$REPO_DIR/librewolf/new-window.desktop"
    local dst="$HOME/.local/share/applications/librewolf-new-window.desktop"

    if [ ! -f "$src" ]; then
        print_info "No librewolf/new-window.desktop in repo — skipping link handler"
        return
    fi

    if ! command -v xdg-mime >/dev/null 2>&1; then
        print_info "xdg-mime unavailable — skipping link handler"
        return
    fi

    mkdir -p "$(dirname "$dst")"
    if ! install -Dm644 "$src" "$dst"; then
        print_error "Could not install link handler: $dst"
        return
    fi

    local mime current changed=0 failed=0
    for mime in x-scheme-handler/http x-scheme-handler/https \
                text/html application/xhtml+xml; do
        current="$(xdg-mime query default "$mime" 2>/dev/null || true)"
        [ "$current" = "librewolf-new-window.desktop" ] && continue
        if xdg-mime default librewolf-new-window.desktop "$mime" >/dev/null 2>&1; then
            changed=1
            print_info "  $mime: ${current:-<unset>} → librewolf-new-window.desktop"
        else
            print_error "Could not set default handler for $mime"
            failed=1
        fi
    done

    [ "$failed" -eq 0 ] || return 1

    if [ "$changed" -eq 0 ]; then
        print_status "Link handler already opens URLs in a new window"
    else
        print_status "Links now open in a new LibreWolf window on the current workspace"
    fi
}
