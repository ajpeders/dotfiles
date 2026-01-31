#!/bin/bash

THEME=$1
ROFI_CONFIG="$HOME/.config/rofi/config.rasi"

if [ -z "$THEME" ]; then
    echo "Available themes:"
    echo "  1. modern    - Clean vertical list with transparency"
    echo "  2. compact   - Horizontal layout, minimal"
    echo "  3. floating  - Centered window, elegant"
    echo ""
    echo "Usage: $0 <theme-name>"
    exit 1
fi

sed -i "s|@theme \"~/.config/rofi/themes/.*\.rasi\"|@theme \"~/.config/rofi/themes/${THEME}.rasi\"|" "$ROFI_CONFIG"
echo "Switched to $THEME theme. Press Super+D to see it!"
