# Architecture

## Overview

The git repo is `~/.config` itself. `scripts/install.sh` bootstraps a machine (packages, links, shell, services); `scripts/update.sh` resyncs it; `scripts/doctor.sh` checks it read-only. Scripts resolve the repo root as `$REPO_DIR` (one level up). macOS clones elsewhere and `macos/install.sh` symlinks into `~/.config`.

```
Hyprland (compositor)
  └─ Noctalia 5 (bar, launcher, notifications, OSD, lock, wallpaper)
       └─ Kitty + Zsh
PipeWire + WirePlumber (audio)
```

Machine differences live in the config, not in branches: monitors are matched by EDID, the touchpad block is ignored where there is no touchpad.

## Hyprland config

Native Lua (Hyprland 0.56+). `hypr/hyprland.lua` requires `hypr/config/*.lua`:

- `defaults.lua` — returns a table (`mainMod`, `terminal`, `filemanager`, `browser`)
- `keybinds.lua` — all binds; Noctalia via `noctalia msg`
- `autostart.lua` — session start (Noctalia service, polkit, hypridle)
- `windowrules.lua`, `animations.lua`, `decorations.lua`, `variables.lua`, `input.lua`, `environment.lua`
- `monitors.lua` — hand-written, see below
- `hypr/noctalia.lua` (gitignored) — rendered border colours, required last

## Theming

One Noctalia palette (`builtin = "Ayu"` in `noctalia/config.toml`) renders templates for Hyprland, kitty, GTK 3/4 and btop. The rendered files are gitignored; only the hand-written rules in each `gtk.css` are tracked, using libadwaita colour names the template defines. yazi is the exception: Noctalia has no yazi template, so it uses the vendored catppuccin-mocha flavor.

## Key decisions

- **Monitors keyed by EDID, positioned absolutely.** `monitors.lua` matches panels by `desc:` (make/model), not connector, and gives known panels absolute coordinates; unknown displays hit an `auto` catch-all. Connector names mean different panels at different desks, and relative `auto-*` placement depended on connection order. `nwg-displays` emits connector-keyed layouts, so it's not used.
- **Noctalia 5 over custom Quickshell.** It ships the whole shell (bar through lock screen, clipboard history included) with a TOML config and no Quickshell dependency.
- **One desktop stack.** A second stack (Omarchy) behind runtime detection cost more than it gave and was removed on 2026-09-26; recover from `b0b8471^` if ever needed.
- **ly** as display manager — minimal TUI.
- **Global git hook.** `git/config` sets `core.hooksPath` to `git/hooks/`, whose `prepare-commit-msg` strips every `Co-Authored-By:` and `Claude-*:` trailer. GitHub HTTPS auth goes through `gh auth git-credential`.
- **Local LLM first.** opencode agents and `claude-local` default to Ollama (`qwen3-coder:30b`); the server's systemd drop-in and firewall gate live in `etc/` and are installed by hand (HOWTO).
