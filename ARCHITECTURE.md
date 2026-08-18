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

- **Monitors keyed by EDID, positioned absolutely** — `hypr/config/monitors.lua` matches panels by `desc:` (make/model) rather than by connector, then gives each known panel absolute coordinates; unknown displays fall through to an `auto` catch-all. Connector names (`DP-2`) identify a port, not a panel, so they mean different monitors at different desks. Relative `auto-*` placement was tried first and dropped: it measures against the whole layout bounding box and depends on monitor connection order, which left a 1920px hole in the top row and could not center the portable panel under both upper panels. Every setup still coexists in one file with no profile switching, no daemon, and no per-machine variants — a rule for an unplugged panel simply never matches. Replaced the previous workflow of hand-swapping `monitors.conf` against a backup file. `nwg-displays` was dropped because it emits connector-keyed layouts.
- **Noctalia over custom Quickshell** — Noctalia provides bar, launcher, notifications, clipboard, OSD, control center, and lock screen out of the box. Custom Quickshell was abandoned due to PipeWire binding issues and complexity.
- **Noctalia wallpaper** — built-in wallpaper manager with Material You color generation, replaces awww
- **ly over SDDM/GDM** — minimal TUI display manager
