# ArchConfig

Hyprland dotfiles for Arch Linux. Includes an install script for fresh setups and an update script for keeping an existing install in sync.

## Stack

| Role | Tool |
|------|------|
| Window manager | Hyprland |
| Terminal | Kitty |
| Shell | Zsh + Oh My Zsh + Powerlevel10k |
| Status bar | Waybar |
| App launcher | Rofi |
| Notifications | SwayNC |
| Wallpaper | awww |
| Dynamic theming | wallust |
| Display manager | ly |
| File manager | Yazi (TUI) / Thunar (GUI) |

## Fresh Install

### Prerequisites

- Arch Linux installed (base system, user account created)
- Internet connection
- Git: `sudo pacman -S git`

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/ajpeders/ArchConfig.git ~/.config

# 2. Run the install script
cd ~/.config
bash install.sh
```

The script will:
1. Install `yay` (AUR helper) if not present
2. Install all packages from `packages.txt`
3. Create `~/Pictures/Screenshots` and `~/Pictures/Wallpapers/generated`
4. Symlink config directories into `~/.config`
5. Set zsh as default shell and install Oh My Zsh, plugins, and Powerlevel10k
6. Enable NetworkManager, bluetooth, pipewire, and wireplumber
7. Install and enable `ly` display manager

### After reboot

```bash
# Configure your prompt (run in a new zsh session)
p10k configure

# Set a wallpaper
awww img ~/.config/wallpapers/wallpaper.jpg --resize crop

# Generate color theme from wallpaper
wallust run ~/.config/wallpapers/wallpaper.jpg
```

Then log out and select **Hyprland** from the ly login screen.

## Keeping in Sync

After pulling changes from this repo on an existing install:

```bash
bash update.sh
```

This will pull the latest commits, install any new packages, re-apply symlinks, and hot-reload Hyprland/Waybar/SwayNC if you're in a session.

## Key Bindings

| Keys | Action |
|------|--------|
| `Super + Return` | Terminal (Kitty) |
| `Super + Space` | App launcher (Rofi) |
| `Super + Q` | Close window |
| `Super + E` | File manager (Yazi) |
| `Super + B` | Browser (Firefox) |
| `Super + F` | Fullscreen |
| `Super + Shift + F` | Float window |
| `Super + V` | Clipboard history |
| `Super + P` | Screenshot |
| `Super + Shift + P` | Screenshot region |
| `Super + Ctrl + P` | Screenshot region → clipboard |
| `Super + Tab` | Cycle monitor focus |
| `Super + 1-5` | Switch workspace |
| `Super + D/S/W/G` | dev / server / work / game workspace |
| `Super + K` | Toggle scratchpad |
| `Super + Shift + Q` | Exit Hyprland |

## Structure

```
~/.config/
├── hypr/               # Hyprland config (split into hypr/config/*.conf)
├── waybar/             # Status bar
├── kitty/              # Terminal
├── rofi/               # App launcher
├── wallust/            # Dynamic theming (templates + hooks)
├── wallpapers/         # Default wallpaper asset
├── zsh/                # Zsh config (ZDOTDIR)
├── gtk-3.0/            # GTK3 theme
├── gtk-4.0/            # GTK4 theme
├── theme/              # Wallust apply scripts
├── install.sh          # Fresh install bootstrap
├── update.sh           # Sync existing install
└── packages.txt        # Package list (pacman + AUR)
```
