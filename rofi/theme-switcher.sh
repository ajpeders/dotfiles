#!/bin/bash
# Rofi Theme Switcher

THEMES_DIR="$HOME/.config/rofi/themes"
CONFIG_FILE="$HOME/.config/rofi/config.rasi"

# List available themes
echo "Available themes:"
echo "1. Modern   - Full featured with blur and gradient"
echo "2. Compact  - Grid layout with large icons"
echo "3. Minimal  - Clean and simple list"
echo "4. Floating - Centered window with big icons"
echo ""
echo "Current theme: $(grep '@theme' "$CONFIG_FILE" | cut -d'"' -f2 | xargs basename | cut -d'.' -f1)"
echo ""
read -p "Select theme (1-4): " choice

case $choice in
    1)
        sed -i 's|@theme.*|@theme "~/.config/rofi/themes/modern.rasi"|' "$CONFIG_FILE"
        echo "✓ Switched to Modern theme"
        ;;
    2)
        sed -i 's|@theme.*|@theme "~/.config/rofi/themes/compact.rasi"|' "$CONFIG_FILE"
        echo "✓ Switched to Compact theme"
        ;;
    3)
        sed -i 's|@theme.*|@theme "~/.config/rofi/themes/minimal.rasi"|' "$CONFIG_FILE"
        echo "✓ Switched to Minimal theme"
        ;;
    4)
        sed -i 's|@theme.*|@theme "~/.config/rofi/themes/floating.rasi"|' "$CONFIG_FILE"
        echo "✓ Switched to Floating theme"
        ;;
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac

echo ""
echo "Press SUPER+Space to test your new theme!"
