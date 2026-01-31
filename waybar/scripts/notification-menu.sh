#!/bin/bash

# Get currently displayed notifications from dunst
count=$(dunstctl count displayed 2>/dev/null)

if [ -z "$count" ] || [ "$count" -eq 0 ]; then
    # Don't show a notification, just exit silently
    exit 0
fi

# Get displayed notifications - use history but filter to only get recent/displayed ones
formatted=$(dunstctl history | jq -r --argjson count "$count" '.data[0][:$count] | .[] | 
    # Map app names to icons
    if .appname.data == "discord" then "" 
    elif .appname.data == "Code" or .appname.data == "code" then "󰨞"
    elif (.appname.data | test("firefox|Firefox")) then ""
    elif (.appname.data | test("spotify|Spotify")) then ""
    elif .appname.data == "notify-send" then "󰍡"
    else "󰂚"
    end + " [" + .appname.data + "] " + .summary.data + 
    (if .body.data != "" then " - " + .body.data else "" end)' 2>/dev/null)

if [ -z "$formatted" ]; then
    exit 1
fi

# Show in rofi with better formatting
echo "$formatted" | rofi -dmenu -p "  Notifications" -i \
    -theme-str 'window { width: 700px; }' \
    -theme-str 'listview { lines: 20; dynamic: true; }' \
    -theme-str 'element-text { font: "JetBrainsMono Nerd Font 11"; }'
