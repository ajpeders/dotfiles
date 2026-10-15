#!/usr/bin/env bash
# Poll playerctl for metadata.
# Format: title\tartist\tstatus (one line per call)
while true; do
    if command -v playerctl >/dev/null 2>&1 && playerctl status &>/dev/null; then
        playerctl metadata --format "{{ lc(title) }}\t{{ lc(artist) }}\t{{ status }}" 2>/dev/null || printf '\t\tStopped\n'
    else
        printf '\t\tStopped\n'
    fi
    sleep 1
done
