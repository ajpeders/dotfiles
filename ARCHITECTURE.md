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

## One Desktop Stack

Every Linux desktop, the M1 Air (Asahi) included, runs Noctalia 5 on Hyprland
with `ly`, hypridle and hand-written monitors. Machine differences live in the
config itself (monitors matched by EDID `desc:`, a touchpad block that is
ignored where there is no touchpad), not in per-machine branches.

**Omarchy removed (2026-09-26).** The Air used to run Omarchy, with
`hypr/hyprland.lua` branching on `/usr/share/omarchy` and the scripts carrying
`--omarchy` detection, split package sections and an sddm path. Keeping two
stacks in step cost more than it gave, so the Air moved to Noctalia and all of
that was deleted. It is recoverable from git history (the commit before
"de-omarchy").

## Config Structure

Hyprland config is native Lua (Hyprland 0.56+), split across `hypr/config/*.lua`
and `require`d from `hypr/hyprland.lua`:

- `defaults.lua` — variables ($mainMod, $terminal, $browser)
- `keybinds.lua` — all keybinds, includes `ipc` (`noctalia msg`) for Noctalia IPC
- `autostart.lua` — exec-once processes
- `windowrules.lua` — window and layer rules
- `animations.lua`, `decorations.lua`, `variables.lua` — visual settings
- `input.lua` — input devices
- `environment.lua` — env vars
- `monitors.lua` — hand-written, portable across setups (see below)
- `hypr/noctalia.lua` (gitignored) — rendered by Noctalia's built-in `hyprland`
  theme template; `hyprland.lua` requires it last, guarded, so the border
  colours follow the active palette

The old hyprlang `.conf` tree was removed once the Lua port landed; recover it
from git history if ever needed.

## Theming

Border colors, kitty colors and the GTK palette all come from Noctalia 5's theme templates (`hypr/noctalia.lua`, `kitty/themes/noctalia.conf`, `gtk-{3,4}.0/noctalia.css`), so one palette (Ayu built-in) drives shell, compositor, terminal and GTK apps. The rendered files are gitignored — they are output that churns on every palette change; only the hand-written rules in each `gtk.css` are tracked, and they use the libadwaita colour names (`@window_bg_color`, `@accent_color`, …) that the template defines. Dynamic theming via wallust was removed (wallust is x86-only and the workflow added more friction than value).

## Key Decisions

- **Monitors keyed by EDID, positioned absolutely** — `hypr/config/monitors.lua` matches panels by `desc:` (make/model) rather than by connector, then gives each known panel absolute coordinates; unknown displays fall through to an `auto` catch-all. Connector names (`DP-2`) identify a port, not a panel, so they mean different monitors at different desks. Relative `auto-*` placement was tried first and dropped: it measures against the whole layout bounding box and depends on monitor connection order, which left a 1920px hole in the top row and could not center the portable panel under both upper panels. Every setup still coexists in one file with no profile switching, no daemon, and no per-machine variants — a rule for an unplugged panel simply never matches. Replaced the previous workflow of hand-swapping `monitors.conf` against a backup file (both now deleted). `nwg-displays` was dropped because it emits connector-keyed layouts.
- **Noctalia over custom Quickshell** — Noctalia provides bar, launcher, notifications, clipboard, OSD, control center, and lock screen out of the box. Custom Quickshell was abandoned due to PipeWire binding issues and complexity.
- **Noctalia 5 (2026-09-09)** — the native C++ rewrite. No Quickshell dependency; config is TOML; clipboard history is built in (cliphist dropped).
- **Noctalia wallpaper** — built-in wallpaper manager with Material You color generation, replaces awww
- **Limine over GRUB (2026-09-12, desktop only)** — the desktop boots Limine 12.8.0 from the removable ESP path (`/boot/EFI/BOOT/BOOTX64.EFI`), which is where GRUB already lived, so the existing firmware entry was inherited unchanged. Config is a hand-written `/boot/limine.conf` rather than anything generated, and a pacman hook re-copies the EFI binary on `limine` upgrades. Deliberately **not** tracked here: `/boot` is outside `~/.config`, and the config is machine-specific (root UUID, Windows ESP GUID). Both `linux-zen` and stock `linux` stay installed — with GRUB gone, the second kernel is the only in-place recovery path.
- **ly over SDDM/GDM** — minimal TUI display manager
