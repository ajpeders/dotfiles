# Dotfiles — ~/.config

Cross-platform dotfiles. The git repo *is* `~/.config`, so `install.sh`'s
symlink phase is a no-op on a machine that was bootstrapped by cloning here.

## Two desktop stacks

This repo supports two Linux desktops. Scripts pick one automatically by
checking whether the `omarchy` pacman package is installed; override with
`--omarchy` / `--no-omarchy`. The choice is recorded in
`~/.local/state/dotfiles-desktop`.

| | **Omarchy** (this machine, `alarm` branch) | **Noctalia** (other Linux boxes) |
|---|---|---|
| Hyprland config | `hypr/*.lua` (Omarchy loads `hyprland.lua`) | `hypr/hyprland.conf` + `hypr/config/*.conf` |
| Shell / bar | Omarchy shell (Quickshell) via `omarchy-launch-shell` | `noctalia-shell` systemd user service |
| Quickshell pkg | upstream `quickshell` | `noctalia-qs` (fork) |
| Display manager | sddm (an `omarchy` dependency) | `ly` |
| Idle / lock | `omarchy/shell.json` -> `idle.screensaver`, `idle.lock` | `hypr/hypridle-{ac,battery}.conf` + `scripts/hypridle-power.sh` |
| Theming | `omarchy theme set <name>` | static palette in `hypr/config/colors.conf` |
| Config dir linked | `omarchy/` | `noctalia/` |

**`noctalia-qs` and `quickshell` are mutually exclusive.** `noctalia-qs`
declares `Provides: quickshell` *and* `Conflicts: quickshell`, so installing it
first makes pacman consider Omarchy's `quickshell` dependency satisfied. The
Omarchy shell then crashes at startup with a Qt `symbol lookup error` and there
is no bar, no notifications and no OSD. `packages.txt` puts each package in its
own gated section so a resync can never reintroduce this.

## Omarchy specifics

- **Never edit `/usr/share/omarchy/`** — package-owned, overwritten on update.
  Reading it is fine and is the best reference.
- User Hyprland overrides load *after* Omarchy's defaults; keep only genuine
  deltas in `hypr/{input,looknfeel,bindings,monitors,autostart}.lua`.
- Rebinding a key that Omarchy already binds requires `hl.unbind(...)` first.
- Validate every Hyprland change with `hyprctl reload && hyprctl configerrors`.
  A reload succeeds even when the config has errors, so always check both.
- `omarchy menu keybindings --print` lists all 238 default binds.
- Omarchy provides its own polkit agent and clipboard history, so `polkit-gnome`
  and `cliphist` are not needed on this stack.

## Machine notes (`alarm` branch — M1 Air, Asahi)

- Single internal display `eDP-1` @ 2560x1600. `hypr/monitors.conf` in this repo
  describes the *desktop* (three DP outputs) and is not used on this machine.
- Always-on "kitchen Alexis" host: never idle-suspend. Enforced by
  `/etc/systemd/logind.conf.d/10-kitchen-power.conf` (`HandleLidSwitch=ignore`,
  `IdleAction=ignore`). Omarchy's idle only dims and locks, so it does not
  conflict.
- Apple Silicon speakers need `asahi-audio` + `speakersafetyd`.

## Shell

Zsh via `ZDOTDIR=~/.config/zsh` (set in `~/.zshenv`), Oh My Zsh +
Powerlevel10k. There is deliberately **no `~/.zshrc`** — it would be dead
weight next to `ZDOTDIR`, and a stock Oh-My-Zsh copy there caused confusion
after the Omarchy install. Omarchy ships a `starship.toml`, but nothing sources
it and no Omarchy theme drives it, so p10k stays.
