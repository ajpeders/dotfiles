# Dotfiles — ~/.config

Cross-platform dotfiles. On Arch the git repo *is* `~/.config`, so `scripts/install.sh`'s symlink phase is a no-op on a machine bootstrapped by cloning here. macOS lives under `macos/`.

## Linux desktop

One stack everywhere, the M1 Air (Asahi) included: Hyprland + Noctalia 5 + `ly`. Omarchy was removed on 2026-09-26 — don't reintroduce stack detection, `hypr/omarchy/`, or an `omarchy/` config dir. `packages-asahi.txt` is added on aarch64 only. `HOWTO.md` → "Migrate off Omarchy" covers converting a machine that still runs it.

The Air is the always-on "kitchen Alexis" host: never idle-suspend. hypridle never suspends on either profile, and `/etc/systemd/logind.conf.d/10-kitchen-power.conf` backs that up.

## Noctalia stack

- **WM:** Hyprland — native Lua config (0.56+); sub-configs in `hypr/config/*.lua`
- **Shell:** Noctalia 5 (bar, launcher, notifications, OSD, control center, lock screen, clipboard); hand-written config `noctalia/config.toml`, GUI overrides in `~/.local/state/noctalia/settings.toml` (they win)
- **IPC:** `noctalia msg <command>` for keybinds; `noctalia msg --help` lists them
- **Wallpaper / theming:** Noctalia built-in; wallust was removed
- Monitors live in `hypr/config/monitors.lua`, hand-written, matched by `desc:` (EDID make/model). Known panels get absolute coordinates, unknown ones fall through to an `auto` catch-all. Don't use nwg-displays; `monitors.conf` is gone.
- Named workspaces: dev(6), server(7), work(8), game(9), config(10), magic(scratchpad)
- waybar/rofi/swaync configs are legacy — recoverable from commit `9db8483` (`git show 9db8483:rofi/config.rasi`), which was the old `quickshell` branch tip

## Shared

- **Terminal:** Kitty. Colors come from Noctalia's template (`kitty/themes/noctalia.conf`, reloaded via SIGUSR1).
- **Shell:** Zsh (Oh My Zsh + Powerlevel10k) at `zsh/` via `ZDOTDIR`. Deliberately no `~/.zshrc`.
- Validate every Hyprland change with `hyprctl reload && hyprctl configerrors` — a reload succeeds even when the config has errors.
