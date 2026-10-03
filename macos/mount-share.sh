#!/bin/sh
# Mount an optional SMB share, tolerating a network that isn't up yet.
#
# At login the network route may not exist yet. Wait for port 445, then hand off to Finder via
# osascript so it pulls the password from Keychain and makes the mount point.
#
# Runs every 5 minutes from the agent, so it is written to be re-entrant and
# cheap: the common case is "already mounted", which returns immediately. The
# non-zero exit when the share never became reachable drives no retry by itself
# (the interval does that) — it is there so `launchctl print` and a manual
# kickstart report the failure honestly.

CONFIG="$HOME/.config/dotfiles/smb.env"
[ -r "$CONFIG" ] || exit 0
. "$CONFIG"
: "${SMB_HOST:?Set SMB_HOST in $CONFIG}"
: "${SMB_USER:?Set SMB_USER in $CONFIG}"
: "${SMB_SHARE:?Set SMB_SHARE in $CONFIG}"
HOST="$SMB_HOST"   # MUST match the Keychain entry's server name
SHARE="$SMB_SHARE"
MOUNTPOINT="/Volumes/$SHARE"
TIMEOUT=60                  # approx seconds to wait for the tunnel
INTERVAL=2

log() { /usr/bin/logger -t mount.share "$1"; echo "$1"; }

# Already mounted — the common case on the 5-minute re-run.
if /sbin/mount | /usr/bin/grep -q " on $MOUNTPOINT "; then
	exit 0
fi

waited=0
while [ "$waited" -lt "$TIMEOUT" ]; do
	/usr/bin/nc -z -w1 "$HOST" 445 2>/dev/null && break
	/bin/sleep "$INTERVAL"
	waited=$((waited + INTERVAL))
done

if [ "$waited" -ge "$TIMEOUT" ]; then
	log "$HOST:445 unreachable after ~${TIMEOUT}s; leaving it to launchd to retry"
	exit 1
fi

if /usr/bin/osascript -e "mount volume \"smb://$SMB_USER@$HOST/$SHARE\""; then
	log "mounted $MOUNTPOINT"
	exit 0
fi

log "$HOST:445 answered but the mount failed (check the Keychain entry for $HOST)"
exit 1
