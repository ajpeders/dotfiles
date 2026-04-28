# ArchConfig

Hyprland dotfiles for Arch Linux. Includes an install script for fresh setups and an update script for keeping an existing install in sync.

## Stack

| Role | Tool |
|------|------|
| Window manager | Hyprland |
| Desktop shell | Noctalia (bar, launcher, notifications, OSD, control center) |
| Terminal | Kitty |
| Shell | Zsh + Oh My Zsh + Powerlevel10k |
| Wallpaper | Noctalia (built-in) |
| Dynamic theming | wallust (Kanagawa-Wave) |
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
8. Apply the Kanagawa-Wave wallust theme

### After reboot

```bash
# Configure your prompt (run in a new zsh session)
p10k configure

# Reapply the default color theme
wallust theme Kanagawa-Wave
```

Then log out and select **Hyprland** from the ly login screen.

## Keeping in Sync

After pulling changes from this repo on an existing install:

```bash
bash update.sh
```

This will pull the latest commits, install any new packages, re-apply symlinks, and hot-reload Hyprland if you're in a session.

## Key Bindings

| Keys | Action |
|------|--------|
| `Super + Return` | Terminal (Kitty) |
| `Super + Space` | App launcher (Noctalia) |
| `Super + Q` | Close window |
| `Super + E` | Browser (Librewolf) |
| `Super + B` | btop |
| `Super + F` | Fullscreen |
| `Super + Shift + F` | Float window |
| `Super + V` | Clipboard history |
| `Super + N` | Notification history |
| `Super + A` | Control center |
| `Super + ,` | Settings |
| `Super + L` | Lock screen |
| `Super + O` | Session menu |
| `Super + P` | Screenshot |
| `Super + Shift + P` | Screenshot region |
| `Super + Ctrl + P` | Screenshot region to clipboard |
| `Super + Tab` | Cycle monitor focus |
| `Super + 1-5` | Switch workspace |
| `Super + D/S/W/G` | dev / server / work / game workspace |
| `Super + K` | Toggle scratchpad |
| `Super + Shift + Q` | Exit Hyprland |

## Structure

```
~/.config/
├── hypr/               # Hyprland config (split into hypr/config/*.conf)
├── kitty/              # Terminal
├── noctalia/           # Noctalia shell user config
├── wallust/            # Dynamic theming (templates + hooks)
├── yazi/               # Yazi file manager config
├── wallpapers/         # Default wallpaper asset
├── zsh/                # Zsh config (ZDOTDIR)
├── gtk-3.0/            # GTK3 theme
├── gtk-4.0/            # GTK4 theme
├── theme/              # Wallust color output
├── install.sh          # Fresh install bootstrap
├── update.sh           # Sync existing install
└── packages.txt        # Package list (pacman + AUR)
```
