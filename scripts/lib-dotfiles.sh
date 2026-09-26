#!/bin/bash
# Shared helpers for scripts/install.sh, update.sh and install-debian.sh.
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
DOTFILES_DESKTOP_DIRS=(hypr kitty gtk-3.0 gtk-4.0 noctalia)

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

    for launcher in claude-local opencode-local opencode-cloud; do
        _dotfiles_link "$REPO_DIR/scripts/$launcher" "$HOME/.local/bin/$launcher"
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

# dotfiles_librewolf_policies -- install librewolf/policies.json if Librewolf
# is installed and the system copy differs.
dotfiles_librewolf_policies() {
    local src="$REPO_DIR/librewolf/policies.json"
    local dst="/etc/librewolf/policies/policies.json"

    if [ ! -f "$src" ]; then
        print_info "No librewolf/policies.json in repo — skipping"
        return
    fi

    if ! pacman -Qq librewolf >/dev/null 2>&1; then
        print_info "Librewolf is not installed — skipping policies"
        return
    fi

    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        print_status "Librewolf policies already up to date"
        return
    fi

    print_info "Installing Librewolf policies to $dst (requires sudo)..."
    sudo install -Dm644 "$src" "$dst"
    print_status "Librewolf policies installed; restart Librewolf to apply"
}
