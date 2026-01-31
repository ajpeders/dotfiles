#!/bin/bash

# Count currently displayed notifications from dunst
count=$(dunstctl count displayed 2>/dev/null)

# Default to 0 if empty or error
if [ -z "$count" ] || ! [[ "$count" =~ ^[0-9]+$ ]]; then
    count=0
fi

if [ "$count" -gt 0 ]; then
    echo "󰂚 $count"
else
    echo "󰂚"
fi
