# Architecture

## Overview

Dotfiles managed as a git repo at `~/.config/`. The `install.sh` script symlinks tracked directories into `~/.config` on a fresh machine. Updates are pulled and synced with `update.sh`.

## Layers

```
┌─────────────────────────────────────────┐
│         Hyprland (compositor)           │
├─────────────────────────────────────────┤
│   Noctalia (shell + wallpaper)          │
├─────────────────────────────────────────┤
│         Kitty + Zsh (terminal)          │
├─────────────────────────────────────────┤
│     PipeWire + WirePlumber (audio)      │
└─────────────────────────────────────────┘
```

## Config Structure

Hyprland config is native Lua (Hyprland 0.56+), split across `hypr/config/*.lua`
and `require`d from `hypr/hyprland.lua`:

- `defaults.lua` — variables ($mainMod, $terminal, $browser)
- `keybinds.lua` — all keybinds, includes `$ipc` for Noctalia IPC
- `autostart.lua` — exec-once processes
- `windowrules.lua` — window and layer rules
- `animations.lua`, `decorations.lua`, `variables.lua` — visual settings
- `input.lua` — input devices
- `environment.lua` — env vars
- `monitors.lua` — hand-written, portable across setups (see below)
- `noctalia_colors.lua` — parses the hyprlang `noctalia-colors.conf` that
  noctalia-shell generates, and applies it last so it overrides defaults

The old hyprlang `.conf` tree was removed once the Lua port landed; recover it
from git history if ever needed.

## Theming

Border colors come from Noctalia, via `hypr/config/noctalia_colors.lua`. Kitty has its own colors + `background_opacity`. Noctalia has its own theming (Kanagawa built-in). Dynamic theming via wallust was removed (wallust is x86-only and the workflow added more friction than value).

## Key Decisions

- **Monitors keyed by EDID, positioned relatively** — `hypr/config/monitors.lua` matches panels by `desc:` (make/model) and places them with `auto-center-*` instead of absolute coordinates. Connector names (`DP-2`) identify a port, not a panel, so they mean different monitors at different desks; absolute coordinates leave a gap in the layout when a panel is absent. Together these let every setup — home desk, away desk, laptop, ad-hoc display — coexist in one file with no profile switching, no daemon, and no per-machine variants. Replaced the previous workflow of hand-swapping `monitors.conf` against a backup file (both now deleted). `nwg-displays` was dropped because it can only emit connector-keyed absolute layouts.
- **Noctalia over custom Quickshell** — Noctalia provides bar, launcher, notifications, clipboard, OSD, control center, and lock screen out of the box. Custom Quickshell was abandoned due to PipeWire binding issues and complexity.
- **Noctalia wallpaper** — built-in wallpaper manager with Material You color generation, replaces awww
- **ly over SDDM/GDM** — minimal TUI display manager
