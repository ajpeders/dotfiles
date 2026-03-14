#!/bin/bash

# Get current notification count from swaync
count=$(swaync-client -c -sw 2>/dev/null)

if [ -z "$count" ] || ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -eq 0 ]; then
    # Don't show a notification, just exit silently
    exit 0
fi

# Open swaync control center when notifications exist
swaync-client -op -sw >/dev/null 2>&1
