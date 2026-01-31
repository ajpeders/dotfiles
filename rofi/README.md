# Rofi Configuration - Beautiful App Launcher

Your rofi app launcher is now configured with three beautiful themes featuring icons and modern styling!

## 🎨 Available Themes

1. **Modern** (default) - Full-featured theme with:
   - Blur background
   - Gradient selection
   - Large icons (32px)
   - List view
   - Scrollbar

2. **Compact** - Grid layout with:
   - 4x3 grid layout
   - Large icons (48px)
   - Compact design
   - Great for mouse users

3. **Minimal** - Clean and simple:
   - Streamlined interface
   - Medium icons (28px)
   - List view
   - Minimal distractions

## 🚀 Usage

### Launch App Launcher
Press: `SUPER + Space` (configured in hyprland.conf)

Or run manually:
```bash
rofi -show drun
```

### Switch Themes
Run the theme switcher:
```bash
~/.config/rofi/theme-switcher.sh
```

Or manually edit `~/.config/rofi/config.rasi` and change the theme line:
```
@theme "~/.config/rofi/themes/modern.rasi"
@theme "~/.config/rofi/themes/compact.rasi"
@theme "~/.config/rofi/themes/minimal.rasi"
```

## 📋 Features

- **Icons**: Enabled with Papirus-Dark icon theme
- **Fuzzy Search**: Type any part of an app name
- **Multiple Modes**: drun (apps), run (commands), window (switch windows)
- **Keyboard Shortcuts**:
  - `↑/↓` or `Ctrl+k/j`: Navigate
  - `Enter`: Launch app
  - `Ctrl+Tab`: Switch modes
  - `Esc`: Close

## 🎨 Customization

All themes use your existing color scheme from `~/.config/theme/colors.css`:
- Background: `#0f0f17`
- Accent: `#89b4fa` (blue)
- Text: `#d8dee9`

### Adjust Icon Size
Edit the theme file and change:
```css
element-icon {
    size: 32px;  /* Change this value */
}
```

### Change Window Size
Edit the theme file:
```css
window {
    width: 700px;  /* Adjust width */
}
```

### Change Number of Items
In `config.rasi`:
```
lines: 8;      /* Number of visible items */
columns: 1;    /* Number of columns */
```

## 🔧 Icon Themes

For best results, install an icon theme:
```bash
# Papirus (recommended, already configured)
sudo pacman -S papirus-icon-theme

# Other options:
yay -S tela-icon-theme
yay -S beauty-line-icon-theme
```

Change icon theme in `config.rasi`:
```
icon-theme: "Papirus-Dark";
```

## 📝 Files

- `~/.config/rofi/config.rasi` - Main configuration
- `~/.config/rofi/themes/modern.rasi` - Modern theme
- `~/.config/rofi/themes/compact.rasi` - Compact grid theme
- `~/.config/rofi/themes/minimal.rasi` - Minimal theme
- `~/.config/rofi/theme-switcher.sh` - Quick theme switcher

## 💡 Tips

1. The themes use transparency - they look best over your wallpaper
2. Icons are automatically detected from installed applications
3. Use fuzzy search - type "fire" to find "Firefox"
4. Right-click for context menu (if enabled by app)
5. Use `rofi -show window` to switch between open windows
6. Use `rofi -show run` for command runner

Enjoy your beautiful new app launcher! 🚀
