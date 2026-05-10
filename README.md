# dotfiles

Cross-platform dotfiles. Hyprland desktop on Arch Linux, AeroSpace tiling on macOS, shared configs for shell and TUI tools.

## Stack

| Role | Arch Linux | macOS |
|------|-----------|-------|
| Window manager | Hyprland | AeroSpace |
| Desktop shell | Noctalia (bar, launcher, notifications, OSD, control center) | macOS Finder |
| Terminal | Kitty | Kitty |
| Shell | Zsh + Oh My Zsh + Powerlevel10k | Zsh + Oh My Zsh + Powerlevel10k |
| File manager | Yazi (TUI) / Thunar (GUI) | Yazi (TUI) / Finder |
| Display manager | ly | macOS login |
| VPN | WireGuard (CLI) | WireGuard (App Store) |
| SMB share | autofs / systemd | LaunchAgent (`com.alex.mount.share`) |

## Fresh Install

### Arch Linux

```bash
git clone git@git.thelunadog.com:alex/dotfiles.git ~/.config
cd ~/.config
bash install.sh
```

The Arch script installs `yay`, packages from `packages.txt`, symlinks configs into `~/.config`, sets up zsh, enables `NetworkManager`/`bluetooth`/`pipewire`/`wireplumber`, and installs the `ly` display manager.

After reboot:
```bash
p10k configure
```
Then log out and pick **Hyprland** from ly.

### macOS

```bash
git clone git@git.thelunadog.com:alex/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash macos/install.sh
```

The macOS script installs Homebrew, AeroSpace, kitty, `mas` + WireGuard (App Store), symlinks configs into `~/.config` and `~/Library/LaunchAgents`, and interactively seeds the SMB Keychain entry. See `HOWTO.md` for the manual follow-ups (Full Disk Access for kitty, etc.).

## Keep in Sync

```bash
# Arch only — pull + reinstall packages + relink + hyprctl reload
bash update.sh
```

```bash
# Both — sync private files (wallpapers, SSH hosts, librewolf profile) from a remote host
bash sync-private.sh user@host
```

## Key Bindings

Keybinds match between Hyprland and AeroSpace, with mac substituting `alt` for `super`.

| Hyprland | AeroSpace | Action |
|----------|-----------|--------|
| `Super + Return` | `Alt + Enter` | Terminal (Kitty) |
| `Super + Q` | `Alt + Q` | Close window |
| `Super + E` | `Alt + E` | Browser (Librewolf) |
| `Super + B` | `Alt + B` | btop |
| `Super + F` | `Alt + F` | Fullscreen |
| `Super + Shift + F` | `Alt + Shift + F` | Float toggle |
| `Super + J` | `Alt + J` | Toggle split direction |
| `Super + 1-9` | `Alt + 1-9` | Switch workspace |
| `Super + Shift + 1-9` | `Alt + Shift + 1-9` | Move window to workspace |
| `Super + Tab` | `Alt + Tab` | Cycle monitor focus |
| `Super + arrows` | `Alt + arrows` | Focus direction |
| `Super + Shift + arrows` | `Alt + Shift + arrows` | Move window |
| `Super + Ctrl + arrows` | `Alt + Ctrl + arrows` | Resize window |

Hyprland-only (no mac equivalent): Noctalia bindings (`N`, `,`, `A`, `L`, `O`), screenshots (`P`), magic/special workspace (`K`), media keys.

## Structure

```
dotfiles/
├── hypr/                  # Hyprland config (Linux)
├── kitty/                 # Terminal (shared)
├── noctalia/              # Noctalia shell (Linux)
├── yazi/                  # File manager (shared)
├── zsh/                   # Zsh / p10k config (shared via ZDOTDIR)
├── wallpapers/            # Default wallpaper
├── gtk-3.0/, gtk-4.0/     # GTK theme (Linux)
├── theme/                 # Static colors
├── macos/                 # macOS-only: aerospace, LaunchAgents, install.sh
├── install.sh             # Arch bootstrap
├── update.sh              # Arch resync
├── sync-private.sh        # Cross-platform private file sync
├── packages.txt           # Pacman + AUR package list
└── HOWTO.md, ARCHITECTURE.md, ROADMAP.md
```
