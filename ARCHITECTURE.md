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

Hyprland config is split across `hypr/config/*.conf` and sourced from `hypr/hyprland.conf`:

- `defaults.conf` — variables ($mainMod, $terminal, $browser)
- `keybinds.conf` — all keybinds, includes `$ipc` for Noctalia IPC
- `autostart.conf` — exec-once processes
- `windowrules.conf` — window and layer rules
- `animations.conf`, `decorations.conf`, `variables.conf` — visual settings
- `input.conf` — input devices
- `environment.conf` — env vars
- `monitors.lua` — hand-written, portable across setups (see below)

## Theming

Static palette in `hypr/config/colors.conf` (border colors). Kitty has its own colors + `background_opacity`. Noctalia has its own theming (Kanagawa built-in). Dynamic theming via wallust was removed (wallust is x86-only and the workflow added more friction than value).

## Key Decisions

- **Monitors keyed by EDID, positioned relatively** — `hypr/config/monitors.lua` matches panels by `desc:` (make/model) and places them with `auto-center-*` instead of absolute coordinates. Connector names (`DP-2`) identify a port, not a panel, so they mean different monitors at different desks; absolute coordinates leave a gap in the layout when a panel is absent. Together these let every setup — home desk, away desk, laptop, ad-hoc display — coexist in one file with no profile switching, no daemon, and no per-machine variants. Replaced the previous workflow of hand-swapping `monitors.conf` against a backup file. `nwg-displays` was dropped because it can only emit connector-keyed absolute layouts.
- **Noctalia over custom Quickshell** — Noctalia provides bar, launcher, notifications, clipboard, OSD, control center, and lock screen out of the box. Custom Quickshell was abandoned due to PipeWire binding issues and complexity.
- **Noctalia wallpaper** — built-in wallpaper manager with Material You color generation, replaces awww
- **ly over SDDM/GDM** — minimal TUI display manager
