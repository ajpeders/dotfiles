# Shared helpers for the per-host installers under hosts/<name>/install.sh.
# Source this; don't run it.
#
# link_home NAME — symlink $HOME/NAME to the calling host profile's copy.
# Idempotent. A real file that would be replaced is kept as NAME.pre-dotfiles
# next to the original; an existing symlink (even to an old repo location) is
# just repointed, since the repo remains the source of truth.
#
# Callers must set HOST_DIR to their own directory before sourcing:
#   HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${YELLOW}[i]${NC} $1"; }

require_not_root() {
    if [ "$EUID" -eq 0 ]; then
        err "Run as your user, not root — symlinks must land in your \$HOME"
        exit 1
    fi
}

link_home() {
    local name="$1"
    local src="$HOST_DIR/$name"
    local dst="$HOME/$name"
    if [ ! -e "$src" ]; then
        err "$name missing from $HOST_DIR — nothing to link"
        return 1
    fi
    if [ "$(readlink -f "$dst" 2>/dev/null)" = "$src" ]; then
        ok "$name already linked"
        return 0
    fi
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.pre-dotfiles"
        info "$name existed — backed up to $name.pre-dotfiles"
    fi
    ln -sfn "$src" "$dst"
    ok "$name -> hosts/$(basename "$HOST_DIR")/$name"
}
