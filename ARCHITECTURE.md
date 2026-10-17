# Architecture

## Overview

The git repo is `~/.config` itself. `scripts/install.sh` bootstraps a machine (packages, links, shell, services); `scripts/update.sh` resyncs it; `scripts/doctor.sh` checks it read-only; `scripts/uninstall.sh` removes only the links it made. Scripts resolve the repo root as `$REPO_DIR` (one level up). macOS clones elsewhere and `macos/install.sh` symlinks into `~/.config`.

```
Hyprland (compositor)
  └─ JetShell (Quickshell: bar, launcher, notifications, clipboard, wallpaper)
       └─ Kitty + Zsh
PipeWire + WirePlumber (audio)
```

Machine differences live in the config, not in branches: monitors are matched by EDID, the touchpad block is ignored where there is no touchpad.

## Hyprland config

Native Lua (Hyprland 0.56+). `hypr/hyprland.lua` requires `hypr/config/*.lua`:

- `defaults.lua` — returns a table (`mainMod`, `terminal`, `filemanager`, `browser`)
- `keybinds.lua` — all binds; shell actions via `jetshell ipc`
- `autostart.lua` — session start (starts `jetshell.service`, polkit, hypridle)
- `windowrules.lua`, `animations.lua`, `decorations.lua`, `variables.lua`, `input.lua`, `environment.lua`
- `monitors.lua` — hand-written, see below

## Theming

Quickshell renders the kitty palette at runtime (`jetshell/sync-kitty-theme.sh`). The GTK palettes (`gtk-{3,4}.0/quickshell.css`) are frozen copies until Quickshell renders them too (see ROADMAP); only the hand-written rules in each `gtk.css` are tracked, using libadwaita colour names. yazi uses the vendored catppuccin-mocha flavor.

## Key decisions

- **Monitors keyed by EDID, positioned absolutely.** `monitors.lua` matches panels by `desc:` (make/model), not connector, and gives known panels absolute coordinates; unknown displays hit an `auto` catch-all. Connector names mean different panels at different desks, and relative `auto-*` placement depended on connection order. `nwg-displays` emits connector-keyed layouts, so it's not used.
- **Custom shell: JetShell.** Noctalia 5 was removed 2026-10-15 in favour of this repo's own Quickshell config (bar, launcher, notifications, wallpaper, theme, clipboard history). A session menu, caffeine and a brightness/volume OSD are still missing (ROADMAP).
- **One desktop stack.** A second stack (Omarchy) behind runtime detection cost more than it gave and was removed on 2026-09-26; recover from `b0b8471^` if ever needed.
- **ly** as display manager — minimal TUI.
- **Global git hook.** `git/config` sets `core.hooksPath` to `git/hooks/`, whose `prepare-commit-msg` strips every `Co-Authored-By:` and `Claude-*:` trailer. GitHub HTTPS auth goes through `gh auth git-credential`.
- **Local LLM first.** opencode agents default to Ollama (`qwen3.6:35b-a3b`); `etc/` ships local-only examples of the server's systemd drop-in and firewall gate; per-machine copies live in `~/.local/state/dotfiles/` and are installed by hand (HOWTO).
