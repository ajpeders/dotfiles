# Architecture

## Overview

Dotfiles managed as a git repo at `~/.config/`. The `scripts/install.sh` script symlinks tracked directories into `~/.config` on a fresh machine. Updates are pulled and synced with `scripts/update.sh`. Bootstrap and maintenance entry points all live in `scripts/`; they resolve the repo root as `$REPO_DIR` (one level up from the script).

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

- **Monitors keyed by EDID, positioned absolutely** — `hypr/config/monitors.lua` matches panels by `desc:` (make/model) rather than by connector, then gives each known panel absolute coordinates; unknown displays fall through to an `auto` catch-all. Connector names (`DP-2`) identify a port, not a panel, so they mean different monitors at different desks. Relative `auto-*` placement was tried first and dropped: it measures against the whole layout bounding box and depends on monitor connection order, which left a 1920px hole in the top row and could not center the portable panel under both upper panels. Every setup still coexists in one file with no profile switching, no daemon, and no per-machine variants — a rule for an unplugged panel simply never matches. Replaced the previous workflow of hand-swapping `monitors.conf` against a backup file (both now deleted). `nwg-displays` was dropped because it emits connector-keyed layouts.
- **Noctalia over custom Quickshell** — Noctalia provides bar, launcher, notifications, clipboard, OSD, control center, and lock screen out of the box. Custom Quickshell was abandoned due to PipeWire binding issues and complexity.
- **Noctalia wallpaper** — built-in wallpaper manager with Material You color generation, replaces awww
- **ly over SDDM/GDM** — minimal TUI display manager
