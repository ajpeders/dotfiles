# dotfiles

Cross-platform dotfiles. Hyprland desktop on Arch Linux, AeroSpace tiling on macOS, shared configs for shell and TUI tools.

## Stack

Linux comes in two flavours; the scripts detect which one a machine runs (see
[Desktop stacks](#desktop-stacks)).

| Role | Arch Linux | macOS |
|------|-----------|-------|
| Window manager | Hyprland | AeroSpace |
| Desktop shell | Omarchy shell, or Noctalia on pre-Omarchy boxes | macOS Finder |
| Terminal | Kitty | Kitty |
| Shell | Zsh + Oh My Zsh + Powerlevel10k | Zsh + Oh My Zsh + Powerlevel10k |
| File manager | Yazi (TUI) / Thunar (GUI) | Yazi (TUI) / Finder |
| Display manager | sddm (Omarchy) / ly (Noctalia) | macOS login |
| VPN | AmneziaWG (`vpn-up`) + Tailscale (`ts-up`) — see [HOWTO](HOWTO.md#vpn) | WireGuard (App Store) |
| SMB share | autofs / systemd | LaunchAgent (`com.alex.mount.share`) |

## Desktop stacks

Omarchy 4.x ships its own Hyprland config, shell, themes and display manager.
Where it is installed it owns the desktop, and this repo only carries the
personal overrides on top. Older Linux machines keep the original
Noctalia + `ly` desktop.

`install.sh` and `update.sh` choose by checking for the `omarchy` package:

```bash
bash install.sh                # auto-detect
bash install.sh --no-omarchy   # force the Noctalia stack
bash install.sh --omarchy      # force the Omarchy stack
```

The result is recorded in `~/.local/state/dotfiles-desktop`. `packages.txt` is
split by the same markers, so an Omarchy box never installs `noctalia-shell`,
`ly` or `hypridle`, and a Noctalia box never installs upstream `quickshell`.

> **Do not install `noctalia-qs` on an Omarchy machine.** It declares both
> `Provides: quickshell` and `Conflicts: quickshell`, so pacman treats
> Omarchy's dependency as already satisfied and the Omarchy shell dies at
> startup with a Qt symbol lookup error — no bar, no notifications, no OSD.

On the Omarchy stack, personal Hyprland overrides live in `hypr/*.lua` and load
*after* Omarchy's defaults. Check bindings with `omarchy menu keybindings
--print`, and validate any change with `hyprctl reload && hyprctl configerrors`.

## Fresh Install

### Arch Linux

```bash
git clone git@git.thelunadog.com:alex/dotfiles.git ~/.config
cd ~/.config
bash install.sh
```

The Arch script installs `paru`, packages from `packages.txt`, symlinks configs into `~/.config`, sets up zsh, and enables `NetworkManager`/`bluetooth`/`pipewire`/`wireplumber`. On a Noctalia machine it also installs and enables the `ly` display manager; on an Omarchy machine it leaves the display manager alone, since Omarchy depends on sddm and enabling `ly` would disable it.

After reboot:
```bash
p10k configure
```
On a Noctalia machine, log out and pick **Hyprland** from ly. On an Omarchy
machine sddm starts the session directly; confirm the bar came up with
`omarchy restart shell`.

### Arch Linux — headless

For servers / boxes you only SSH into:

```bash
bash install.sh --headless
```

Installs only the CLI base from `packages.txt` (zsh, neovim, git, mosh, openssh, tmux, etc.), links the CLI dotfiles (`zsh`, `nvim`, `tmux`, `yazi`, `git`), enables `sshd`, and switches the system to `multi-user.target` (no display manager). `update.sh` reads the mode from `~/.local/state/dotfiles-mode` and stays in headless mode on resync; pass `--full` to override.

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

**On the Omarchy stack this table does not apply** — Omarchy ships ~238 of its
own bindings and they are the source of truth. List them with `omarchy menu
keybindings --print`. `hypr/bindings.lua` documents how each binding below maps
onto its Omarchy equivalent, with ready-to-uncomment overrides if the defaults
fight muscle memory.

The table below describes the Noctalia stack, where keybinds match between
Hyprland and AeroSpace, with mac substituting `alt` for `super`.

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
│   ├── *.lua              #   Omarchy stack: overrides loaded after its defaults
│   └── hyprland.conf, config/  #   Noctalia stack: standalone config
├── omarchy/               # Omarchy shell/bar, menu extensions, hooks (Linux)
├── kitty/                 # Terminal (shared)
├── noctalia/              # Noctalia shell (Linux, pre-Omarchy machines)
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
