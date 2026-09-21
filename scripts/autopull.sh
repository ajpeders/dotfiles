#!/usr/bin/env bash
# Fast-forward this dotfiles clone to GitHub main. Runs every 15 min from a
# systemd user timer (Linux) or LaunchAgent (macOS) so every machine picks up
# config changes without a manual pull.
#
# Never merges or overwrites local work: diverged history, or uncommitted
# edits to a file the update touches, make the merge refuse and the run fail
# (journalctl --user -u dotfiles-autopull / /tmp/com.alex.dotfiles-autopull.err).
# Fetches over HTTPS from the public GitHub mirror, so it needs no SSH agent.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

URL=https://github.com/ajpeders/dotfiles.git
branch=$(git symbolic-ref --quiet --short HEAD) || { echo "detached HEAD; skipping"; exit 0; }
[ "$branch" = main ] || { echo "on branch $branch, not main; skipping"; exit 0; }
git fetch --quiet "$URL" main || { echo "fetch failed (offline?); skipping"; exit 0; }

[ "$(git rev-parse HEAD)" = "$(git rev-parse FETCH_HEAD)" ] && exit 0
git merge-base --is-ancestor FETCH_HEAD HEAD && exit 0   # local is ahead: nothing to pull
git merge --ff-only --quiet FETCH_HEAD && echo "updated to $(git log -1 --format='%h %s')"
