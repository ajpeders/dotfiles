# Dotfiles — ~/.config

Cross-platform dotfiles. On Arch the git repo *is* `~/.config`, so `scripts/install.sh`'s symlink phase is a no-op on a machine bootstrapped by cloning here. macOS lives under `macos/`.

## Two Linux desktop stacks

Scripts pick one automatically by checking whether the `omarchy` pacman package is installed; override with `--omarchy` / `--no-omarchy`. The choice is recorded in `~/.local/state/dotfiles-desktop`.

| | **Noctalia** (desktops) | **Omarchy** (M1 Air, Asahi) |
|---|---|---|
| Hyprland config | `hypr/hyprland.lua` → `hypr/config/*.lua` | same entry point → Omarchy bootstrap + overrides in `hypr/omarchy/*.lua` |
| Shell / bar | Noctalia 5 (native C++) as `noctalia-shell.service` | Omarchy shell (Quickshell) via `omarchy-launch-shell` |
| Quickshell pkg | none (v5 has no Qt) | upstream `quickshell` |
| Display manager | `ly` | sddm (an `omarchy` dependency) |
| Idle / lock | `hypr/hypridle-{ac,battery}.conf` + `hypr/scripts/hypridle-power.sh` | `omarchy/shell.json` → `idle.screensaver`, `idle.lock` |
| Theming | Noctalia templates render `hypr/noctalia.lua` + `kitty/themes/noctalia.conf` | `omarchy theme set <name>` |
| Config dir linked | `noctalia/` | `omarchy/` |

`hypr/hyprland.lua` branches at runtime on `/usr/share/omarchy` being present, so one file serves both. `packages.txt` has `NOCTALIA` / `OMARCHY` sections gated by the same detection; `packages-asahi.txt` is added on aarch64 only.

**Never install the legacy `noctalia-qs`** (Noctalia 4's Quickshell fork) on an Omarchy machine: it Provides+Conflicts `quickshell` and the Omarchy shell dies with a Qt symbol lookup error. Noctalia 5 has no Quickshell dependency, so this only bites if v4 is reinstalled. `verify_omarchy_shell_stack` in install.sh checks for it.

## Noctalia stack

- **WM:** Hyprland — native Lua config (0.56+); sub-configs in `hypr/config/*.lua`
- **Shell:** Noctalia 5 (bar, launcher, notifications, OSD, control center, lock screen, clipboard); hand-written config `noctalia/config.toml`, GUI overrides in `~/.local/state/noctalia/settings.toml` (they win)
- **IPC:** `noctalia msg <command>` for keybinds; `noctalia msg --help` lists them
- **Wallpaper / theming:** Noctalia built-in; wallust was removed
- Monitors live in `hypr/config/monitors.lua`, hand-written, matched by `desc:` (EDID make/model). Known panels get absolute coordinates, unknown ones fall through to an `auto` catch-all. Don't use nwg-displays; `monitors.conf` is gone.
- Named workspaces: dev(6), server(7), work(8), game(9), config(10), magic(scratchpad)
- waybar/rofi/swaync configs are legacy (kept on the `quickshell` branch)

## Omarchy stack

- **Never edit `/usr/share/omarchy/`** — package-owned, overwritten on update. Reading it is fine and is the best reference.
- Keep only genuine deltas in the `hypr/omarchy/*.lua` overrides. Rebinding a key Omarchy already binds requires `hl.unbind(...)` first. `omarchy menu keybindings --print` lists the defaults.
- Omarchy provides its own polkit agent and clipboard history, so `polkit-gnome` and `cliphist` are not needed there.
- `scripts/install.sh --install-omarchy` (aarch64 only) bootstraps Omarchy via omarchy-mac `quattro` in `~/.local/share/omarchy`, *before* the dotfiles phase because its installer overwrites tracked configs.
- The Air is the always-on "kitchen Alexis" host: never idle-suspend. Enforced by `/etc/systemd/logind.conf.d/10-kitchen-power.conf`.

## Shared

- **Terminal:** Kitty. `kitty/kitty.conf` includes both stacks' theme files; whichever exists wins.
- **Shell:** Zsh (Oh My Zsh + Powerlevel10k) at `zsh/` via `ZDOTDIR`. Deliberately no `~/.zshrc`.
- Validate every Hyprland change with `hyprctl reload && hyprctl configerrors` — a reload succeeds even when the config has errors.
