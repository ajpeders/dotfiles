# dotfiles

Cross-platform dotfiles. Hyprland desktop on Arch Linux, AeroSpace tiling on macOS, shared configs for shell and TUI tools.

## Stack

Linux comes in two flavours; the scripts detect which one a machine runs (see
[Desktop stacks](#desktop-stacks)).

| Role | Arch Linux | macOS |
|------|-----------|-------|
| Window manager | Hyprland | AeroSpace |
| Desktop shell | Noctalia 5 (desktops) or Omarchy shell (M1 Air) | macOS Finder |
| Terminal | Kitty | Kitty |
| Shell | Zsh + Oh My Zsh + Powerlevel10k | Zsh + Oh My Zsh + Powerlevel10k |
| File manager | Yazi (TUI) / Thunar (GUI) | Yazi (TUI) / Finder |
| Display manager | sddm (Omarchy) / ly (Noctalia) | macOS login |
| VPN | AmneziaWG (`vpn-up`) + Tailscale (`tailscaled.service`, `ts-up`) — see [HOWTO](HOWTO.md#vpn) | WireGuard (App Store) + Tailscale (LaunchAgent `com.alex.tailscale`) |
| SMB share | autofs / systemd | LaunchAgent (`com.alex.mount.share`) |

## Desktop stacks

Omarchy 4.x ships its own Hyprland config, shell, themes and display manager.
Where it is installed it owns the desktop, and this repo only carries the
personal overrides on top. Older Linux machines keep the original
Noctalia + `ly` desktop.

`scripts/install.sh` and `scripts/update.sh` choose by checking for the `omarchy` package:

```bash
bash scripts/install.sh                # auto-detect
bash scripts/install.sh --no-omarchy   # force the Noctalia stack
bash scripts/install.sh --omarchy      # force the Omarchy stack
```

The result is recorded in `~/.local/state/dotfiles-desktop`. `packages.txt` is
split by the same markers, so an Omarchy box never installs `noctalia`,
`ly` or `hypridle`, and a Noctalia box never installs `quickshell`.

### Installing Omarchy from here

On a machine that does not have Omarchy yet:

```bash
bash scripts/install.sh --install-omarchy     # implies --omarchy; aarch64 only
```

This runs *before* the dotfiles phase, because Omarchy's installer ends in
`seed_user_defaults`, which copies its stock configs into `~/.config` and will
overwrite tracked files. Applying dotfiles afterwards is what makes ours win.

Apple Silicon cannot use the upstream route: Omarchy 4 installs from an ISO
that has no aarch64 build and cannot boot a Mac. The flag therefore delegates
to [omarchy-mac](https://github.com/omacom/omarchy-mac) (branch `quattro`),
which builds the `arch=any` Omarchy packages from a checkout in
`~/.local/share/omarchy` and installs them the way the ISO would. Without the
flag nothing is installed — bootstrapping a desktop should never be a side
effect of a resync. On x86_64 the phase refuses and points at omarchy.org
rather than guessing.

Omarchy's own `bootstrap.sh` is a different thing and is *not* wired in: it
runs as root on a bare Asahi system and creates the user account, so it has to
run before these dotfiles exist.

After install (and on every run where Omarchy is present) the phase asserts the
shell stack is sound — real `quickshell` present, `noctalia-qs` absent, and the
binary actually executes. That combination failed silently on this machine and
cost a working desktop.

> **Do not install `noctalia-qs` on an Omarchy machine.** It declares both
> `Provides: quickshell` and `Conflicts: quickshell`, so pacman treats
> Omarchy's dependency as already satisfied and the Omarchy shell dies at
> startup with a Qt symbol lookup error — no bar, no notifications, no OSD.

Both stacks share `hypr/hyprland.lua`: it detects Omarchy at runtime and either
bootstraps Omarchy and loads the personal overrides in `hypr/omarchy/*.lua`, or loads the
Noctalia config from `hypr/config/*.lua`. Omarchy overrides load *after* its defaults. Check bindings with `omarchy menu keybindings
--print`, and validate any change with `hyprctl reload && hyprctl configerrors`.

## Fresh Install

### Arch Linux

```bash
git clone git@git.thelunadog.com:alex/dotfiles.git ~/.config
cd ~/.config
bash scripts/install.sh
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
# Both — sync private files (wallpapers, SSH hosts, librewolf profile) from a remote host
bash scripts/sync-private.sh user@host
```

```bash
# Both — point opencode at a local Ollama / llama.cpp / OpenAI-compatible server
bash scripts/setup-llm.sh [base-url]
```

Prompts for the server's base URL (or takes it as an argument), confirms it
responds on `/v1/models`, and lets you pick from the models it serves. Both the
URL and the chosen model go to `~/.local/state/dotfiles/llm.env` as
`LLM_SERVER_URL` and `LLM_MODEL`, which `zsh/.zshrc` sources — kept out of the
repo because both differ per machine, and because on Arch the repo *is*
`~/.config`.

Running this is **optional**: `zsh/.zshrc` defaults `LLM_SERVER_URL` to the
local ollama (`http://localhost:11434/v1`) and `LLM_MODEL` to the catalog's
coding default, so a machine with a local ollama needs no setup at all. Run the
script only to point opencode at a different host.

`opencode/opencode.json` stays machine-agnostic: it is a *catalog* declaring
context/output limits per model, and `{env:LLM_MODEL}` selects the default. The
script never rewrites it, so running setup on a second machine no longer dirties
the working tree. Add a `models` entry when you want explicit limits for a model
the catalog does not list yet.

## Key Bindings

**On the Omarchy stack this table does not apply** — Omarchy ships ~238 of its
own bindings and they are the source of truth. List them with `omarchy menu
keybindings --print`. `hypr/omarchy/bindings.lua` documents how each binding below maps
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
├── noctalia/              # Noctalia 5 config.toml (Linux desktops)
├── yazi/                  # File manager (shared)
├── zsh/                   # Zsh / p10k config (shared via ZDOTDIR)
├── wallpapers/            # Default wallpaper
├── gtk-3.0/, gtk-4.0/     # GTK theme (Linux); noctalia.css is generated + gitignored
├── theme/                 # Static colors
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
