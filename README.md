# dotfiles

Cross-platform dotfiles. Hyprland desktop on Arch Linux, AeroSpace tiling on macOS, shared configs for shell and TUI tools.

## Stack

| Role | Arch Linux | macOS |
|------|-----------|-------|
| Window manager | Hyprland | AeroSpace |
| Desktop shell | Noctalia 5 | macOS Finder |
| Terminal | Kitty | Kitty |
| Shell | Zsh + Oh My Zsh + Powerlevel10k | Zsh + Oh My Zsh + Powerlevel10k |
| File manager | Yazi (TUI) / Thunar (GUI) | Yazi (TUI) / Finder |
| Display manager | ly | macOS login |
| VPN | AmneziaWG (`vpn-up`) + Tailscale (`tailscaled.service`, `ts-up`) — see [HOWTO](HOWTO.md#vpn) | WireGuard (App Store) + Tailscale (LaunchAgent `com.alex.tailscale`) |
| SMB share | autofs / systemd | LaunchAgent (`com.alex.mount.share`) |

## Desktop

Every Linux desktop, the M1 Air (Asahi) included, runs Hyprland + Noctalia 5 +
`ly`. Hyprland's entry point is `hypr/hyprland.lua`, which loads
`hypr/config/*.lua`; validate any change with
`hyprctl reload && hyprctl configerrors`.

Omarchy was used on the Air until 2026-09-26 and has been removed. To convert a
machine that still runs it, see [HOWTO](HOWTO.md#migrate-off-omarchy).

## Fresh Install

### Arch Linux

```bash
git clone git@git.thelunadog.com:alex/dotfiles.git ~/.config
cd ~/.config
bash scripts/install.sh
```

The Arch script installs `paru`, packages from `packages.txt`, symlinks configs into `~/.config`, sets up zsh, and enables `NetworkManager`/`bluetooth`/`pipewire`/`wireplumber`. It also installs and enables the `ly` display manager.

After reboot:
```bash
p10k configure
```
Log out and pick **Hyprland** from ly.

### Arch Linux — headless

For servers / boxes you only SSH into:

```bash
bash scripts/install.sh --headless
```

Installs only the CLI base from `packages.txt` (zsh, neovim, git, mosh, openssh, tmux, opencode, etc.), links the CLI dotfiles (`zsh`, `nvim`, `tmux`, `yazi`, `git`), enables `sshd`, and switches the system to `multi-user.target` (no display manager). `scripts/update.sh` reads the mode from `~/.local/state/dotfiles-mode` and stays in headless mode on resync; pass `--full` to override.

### Debian — headless

For Debian/Raspberry Pi boxes (the GUI stack is Arch-only, so there is no full mode):

```bash
git clone git@git.thelunadog.com:alex/dotfiles.git ~/.config
cd ~/.config
bash scripts/install-debian.sh
```

The Debian counterpart to `scripts/install.sh --headless`: `apt`-installs the CLI base (Debian-named — `fd-find`, `openssh-server`, etc.), links the CLI dotfiles (`zsh`, `nvim`, `tmux`, `yazi`, `git`), sets up zsh + oh-my-zsh + powerlevel10k, enables `ssh`, and installs `opencode` via upstream's installer (Debian has no package; Arch gets it from `packages.txt`, macOS from the `Brewfile`). Per-host `$HOME` files live under `hosts/<name>/`; `hosts/livingroom-pi/install.sh --full` links those and then runs this script.

### macOS

```bash
git clone git@git.thelunadog.com:alex/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash macos/install.sh
```

The macOS script installs Homebrew, AeroSpace, kitty, Tailscale, `mas` + WireGuard (App Store), symlinks configs into `~/.config` and `~/Library/LaunchAgents`, and interactively seeds the SMB Keychain entry. See `HOWTO.md` for the manual follow-ups (Full Disk Access for kitty, etc.).

## Keep in Sync

```bash
# Arch only — pull + reinstall packages + relink + hyprctl reload
bash scripts/update.sh
```

```bash
# Both — sync private files from a remote host: wallpapers, SSH host drop-ins,
# rclone remotes, WireGuard configs, gh auth, librewolf profile
bash scripts/sync-private.sh user@host
```

```bash
# Both — point opencode at a local Ollama / llama.cpp / OpenAI-compatible server
bash scripts/setup-llm.sh [base-url]
```

Prompts for the server's base URL (or takes it as an argument), confirms it
responds on `/v1/models`, and lets you pick from the models it serves. Both the
URL and the chosen model go to `~/.local/state/dotfiles/llm.env` as
`LLM_SERVER_URL` and `LLM_MODEL`, which `zsh/.zshrc` sources. The script also
writes the gitignored `environment.d/90-llm-local.conf` and updates systemd's
current user environment so launcher and keybinding launches see the same
values. Machine-specific values stay out of the repo.

Running this is **optional**: the defaults point at a local ollama
(`http://localhost:11434/v1`), so a machine running one needs no setup at all.
They are set in two places on purpose — `environment.d/50-llm.conf` covers the
whole session (systemd units, app launchers, Hyprland keybinds) and
`zsh/.zshrc` covers shells. A shell rc alone is not enough: opencode launched
from a keybind would get an empty `baseURL`, which fails at request time rather
than at startup. Run the script only to point opencode at a different host.

`opencode/opencode.json` is the single tracked global config. It stays
machine-agnostic: it is a *catalog* declaring
context/output limits per model, and `{env:LLM_MODEL}` selects the default. The
script never rewrites it, so running setup on a second machine no longer dirties
the working tree. Add a `models` entry when you want explicit limits for a model
the catalog does not list yet.

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
│   ├── hyprland.lua       #   Entry point; loads config/*.lua
│   └── config/*.lua       #   Split config (monitors, input, keybinds, ...)
├── kitty/                 # Terminal (shared)
├── noctalia/              # Noctalia 5 config.toml (Linux desktops)
├── yazi/                  # File manager (shared)
├── zsh/                   # Zsh / p10k config (shared via ZDOTDIR)
├── opencode/              # OpenCode config for the local remote model
├── wallpapers/            # Default wallpaper
├── keychron/              # Keychron Q1 HE keymap export
├── gtk-3.0/, gtk-4.0/     # GTK theme (Linux); noctalia.css is generated + gitignored
├── macos/                 # macOS-only: aerospace, LaunchAgents, install.sh
├── scripts/               # Bootstrap + maintenance entry points
│   ├── install.sh         # Arch bootstrap
│   ├── install-debian.sh  # Debian headless bootstrap (apt)
│   ├── update.sh          # Arch resync
│   ├── sync-private.sh    # Cross-platform private file sync
│   └── setup-llm.sh       # Point opencode at a local LLM server
├── packages.txt           # Pacman + AUR package list
└── HOWTO.md, ARCHITECTURE.md, ROADMAP.md
```
