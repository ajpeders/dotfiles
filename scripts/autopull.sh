#!/usr/bin/env bash
# Fast-forward this dotfiles clone to Forgejo main (the primary). Runs every 15 min from a
# systemd user timer (Linux) or LaunchAgent (macOS) so every machine picks up
# config changes without a manual pull.
#
# Never merges or overwrites local work: diverged history, or uncommitted
# edits to a file the update touches, make the merge refuse and the run fail
# (journalctl --user -u dotfiles-autopull / /tmp/com.alex.dotfiles-autopull.err).
# Reads Forgejo over this clone's own SSH remote (keys are agentless); if that
# fails, falls back to the public GitHub copy over HTTPS.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

GITHUB=https://github.com/ajpeders/dotfiles.git
FORGEJO=$(git remote -v | awk '/git\.thelunadog\.com.*\(fetch\)/ {print $1; exit}')
branch=$(git symbolic-ref --quiet --short HEAD) || { echo "detached HEAD; skipping"; exit 0; }
[ "$branch" = main ] || { echo "on branch $branch, not main; skipping"; exit 0; }
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"
if ! { [ -n "$FORGEJO" ] && git fetch --quiet "$FORGEJO" main; }; then
    echo "forgejo fetch failed; trying GitHub"
    git fetch --quiet "$GITHUB" main || { echo "fetch failed (offline?); skipping"; exit 0; }
fi

[ "$(git rev-parse HEAD)" = "$(git rev-parse FETCH_HEAD)" ] && exit 0
git merge-base --is-ancestor FETCH_HEAD HEAD && exit 0   # local is ahead: nothing to pull
git merge --ff-only --quiet FETCH_HEAD && echo "updated to $(git log -1 --format='%h %s')"
