#!/usr/bin/env sh

set -eu

follow=$(hyprctl getoption input:follow_mouse | grep -oP 'int: \K\d+')

if [ "$follow" = "0" ]; then
    hyprctl keyword input:follow_mouse 1
    hyprctl notify 1 1500 "rgb(00cc66)" " Mouse freed"
else
    hyprctl keyword input:follow_mouse 0
    hyprctl notify 1 1500 "rgb(ff6600)" " Mouse locked (game mode)"
fi
