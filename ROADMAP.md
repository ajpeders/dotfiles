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

- [ ] **Re-enable SIP on the MacBook Air.** Partially disabled on 2026-09-01 to
      try yabai (`csrutil enable --without fs --without debug --without nvram`
      plus `sudo nvram boot-args=-arm64e_preview_abi`). yabai never worked —
      its scripting addition cannot inject into Dock.app on Apple Silicon +
      Sequoia (asmvik/yabai #2686, #2747) — so the machine is running with
      reduced security for no benefit. From Recovery: `csrutil enable`, then
      after rebooting `sudo nvram -d boot-args`. Watch meanwhile for broken
      Apple Pay, iPhone Mirroring and DRM'd playback.
      The yabai configs stay in the repo in case upstream ever fixes it.
- [ ] Migrate `macos/aerospace/aerospace.toml` to `config-version = 2`
      (AeroSpace warns that version 1 is outdated on every reload)
- [ ] Capture the home desk's second 1440p panel into `hypr/config/monitors.lua`
      (run `hypr/scripts/capture-monitor.sh` while at that desk). Until then it
      falls through to the catch-all rule. The old connector-keyed settings are in
      git history (`git show a328eb5:hypr/monitors.conf.home-backup`), but they
      never recorded the panel's EDID description.
- [ ] Capture the laptop's internal panel (`eDP-1`) the same way, and confirm the
      relative layout behaves when docking/undocking there
- [ ] Test scripts/install.sh on a fresh system
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
