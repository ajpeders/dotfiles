# Roadmap

## Current Status

Desktop shell is functional with Noctalia on Hyprland. Core workflow (launcher, notifications, volume, clipboard, lock screen) all working via Noctalia IPC.

## Done

- [x] Hyprland base config (workspaces, keybinds, window rules)
- [x] Kitty terminal + Zsh/P10k shell
- [x] Noctalia shell (replaced waybar + rofi + swaync)
- [x] Keybinds updated for Noctalia IPC
- [x] Install/update scripts updated
- [x] Stale waybar/rofi/swaync/quickshell references cleaned up
- [x] Portable monitor config — EDID-keyed, one file for all setups
- [x] Established that the Samsung G53F's EDID under-reports (claims 60Hz max).
      Settled on 144Hz: 200Hz link-trains and looks fine idle but drops frames
      under load. Don't raise it without testing a fullscreen game.

## Next

- [ ] Capture the home desk's second 1440p panel into `hypr/config/monitors.lua`
      (run `hypr/scripts/capture-monitor.sh` while at that desk). Until then it
      falls through to the catch-all rule. The old connector-keyed settings are in
      git history (`git show a328eb5:hypr/monitors.conf.home-backup`), but they
      never recorded the panel's EDID description.
- [ ] Capture the laptop's internal panel (`eDP-1`) the same way, and confirm the
      relative layout behaves when docking/undocking there
- [ ] Test install.sh on a fresh system
- [ ] Review wlsunset — Noctalia has built-in night light, may be redundant

## Ideas

- Desktop widgets via Noctalia
- Gaming mode toggle (disable shell animations, notifications)
## Make this usable by others (added 2026-08-27)

- [ ] Universalize the README / docs / code for outside users: document setup
  from scratch on generic infrastructure, replace homelab-specific assumptions
  (private hostnames, LAN addresses, personal paths and defaults) with
  env-driven configuration plus examples, and keep the public GitHub mirror
  directly runnable.
