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
- **`omarchy update` edits tracked terminal configs in place.** Its migrations
  `sed -i`/append straight into `~/.config/kitty/kitty.conf`,
  `~/.config/foot/foot.ini` and `~/.config/alacritty/alacritty.toml` — that is
  where kitty.conf's `listen_on` line and both files' `~/.local/state/omarchy/current`
  include paths came from. Each one is guarded (it skips when the setting is
  already present) and recorded in `~/.local/state/omarchy/migrations/`, so they
  do not re-run, but expect an `omarchy update` to show up as a dirty tree.
  `omarchy-font-set` and `omarchy-display-text-size` rewrite the font size the
  same way. Theming does *not* — see the section below.

## Omarchy's shell without Omarchy

`scripts/omarchy-shell.sh` puts the Omarchy shell (bar, notifications, OSD, menu, lock)
on a Hyprland box that is *not* running Omarchy — the Noctalia machines. It
unpacks the upstream packages under `~/.local/share/omarchy-shell` and points
`OMARCHY_PATH` there, so there is no pacman repo, no keyring, no `/etc`
drop-ins, and no sddm or uwsm pulled in as dependencies. Re-running it is the
update path.

Three things about the packaging that the script exists to handle:

- **Two packages are required.** `omarchy` ships `shell/`, `themes/` and the
  `bin/` symlink farm; `omarchy-settings` ships `config/`, `default/` and
  `applications/`. Unpacking only the first yields helpers that cannot find
  their defaults.
- **`$OMARCHY_PATH/bin` is 428 absolute symlinks into `/usr/bin`**, which is
  where the package puts the real programs. Every one of them dangles without
  the package installed, so the script repoints them at the unpacked copy.
  This is also why `grep -r` over `/usr/share/omarchy/bin` finds nothing —
  it does not follow symlinks; use `grep -r /usr/bin/omarchy*` instead.
- **Hyprland's `env =` lines take literal values** and do not expand `$PATH`,
  so the script writes a `~/.local/bin/omarchy-shell-start` wrapper that
  prepends rather than clobbers, and autostarts that.

`noctalia-qs` still has to go first — the conflict described above is a hard
one, and no machine can run both shells. The script refuses to proceed without
`--replace-noctalia`.

`omarchy theme set` is safe to run here, contrary to what this file used to
say. Verified against Omarchy on foot 1.28: nothing in the `omarchy-theme-set*`
family writes under `~/.config` for a terminal. Themes land in
`~/.local/state/omarchy/current/theme/`, `omarchy-theme-set-templates` renders
into `.../current/next-theme/`, and the tracked `kitty.conf` / `foot.ini` pick
the result up through their `include` lines. The shell falls back to a built-in
palette when no theme is set.

## Shared

- **Terminal:** Kitty everywhere except Omarchy. `kitty/kitty.conf` includes both stacks' theme
  files; whichever exists wins. Omarchy's `SUPER+RETURN` runs `xdg-terminal-exec`, whose only
  preference is `foot.desktop`, so an Omarchy box gets `foot/foot.ini` — kept in step with
  kitty.conf by hand, deltas marked in the file. foot aborts on a missing `include=` (kitty
  skips one), so its Omarchy theme include has to go if Omarchy ever comes off a machine.
- **Shell:** Zsh (Oh My Zsh + Powerlevel10k) at `zsh/` via `ZDOTDIR`. Deliberately no `~/.zshrc`.
- Validate every Hyprland change with `hyprctl reload && hyprctl configerrors` — a reload succeeds even when the config has errors.
