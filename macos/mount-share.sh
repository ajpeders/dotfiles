#!/bin/sh
# Mount the luna SMB share, tolerating a tailnet that isn't up yet.
#
# The share sits on ISIS's LAN address and is only reachable through the
# 192.168.0.0/24 subnet route ISIS advertises. At login that route does not
# exist yet, so mounting immediately (as the old agent did) fails once and
# gives up. Instead: wait for port 445 to answer, then hand off to Finder via
# osascript so it pulls the password from Keychain and makes the mount point.
#
# Exits non-zero when the share never became reachable, which is what drives
# the agent's KeepAlive/SuccessfulExit retry.

HOST=share.thelunadog.com   # MUST match the Keychain entry's server name
SHARE=share
MOUNTPOINT="/Volumes/$SHARE"
TIMEOUT=60                  # approx seconds to wait for the tunnel
INTERVAL=2

log() { /usr/bin/logger -t mount.share "$1"; echo "$1"; }

# Already mounted (e.g. a retry firing after success) — nothing to do.
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

if /usr/bin/osascript -e "mount volume \"smb://ween@$HOST/$SHARE\""; then
	log "mounted $MOUNTPOINT"
	exit 0
fi

log "$HOST:445 answered but the mount failed (check the Keychain entry for $HOST)"
exit 1
