# Roadmap

## Current Status

Desktops run Noctalia 5 (native C++ rewrite, since 2026-09-09) on Hyprland; the M1 Air runs Omarchy. Both stacks live on `main` since 2026-09-09 (the `alarm` and `omarchy` branches were merged), sharing one `hypr/hyprland.lua` that picks the stack at load time.

## Done

- [x] Hyprland base config (workspaces, keybinds, window rules)
- [x] Kitty terminal + Zsh/P10k shell
- [x] Noctalia shell (replaced waybar + rofi + swaync)
- [x] Keybinds updated for Noctalia IPC
- [x] Install/update scripts updated
- [x] Stale waybar/rofi/swaync/quickshell references cleaned up
- [x] Portable monitor config — EDID-keyed, one file for all setups
- [x] Noctalia 4 → 5: TOML config, `noctalia msg` IPC, theme templates for Hyprland + kitty
- [x] Merged the laptop branches: hypridle AC/battery profiles, touchpad gestures,
      brightness submap, VPN helpers, and the Omarchy stack behind runtime detection
- [x] Established that the Samsung G53F's EDID under-reports (claims 60Hz max).
      Settled on 144Hz: 200Hz link-trains and looks fine idle but drops frames
      under load. Don't raise it without testing a fullscreen game.
- [x] GTK apps follow the Noctalia palette (`gtk.css` imports the generated
      `noctalia.css`; the generated files are gitignored)
- [x] Games pinned to workspace 9 — both `steam_app_*` and `gamescope`, since
      under gamescope the outer window's class is `gamescope`
- [x] Desktop moved from GRUB to Limine (2026-09-12) — see ARCHITECTURE.md;
      `/boot/limine.conf` is machine state, intentionally untracked
- [x] Repo audit (2026-09-12): dropped the Noctalia 4 config (`settings.json`,
      QML plugins, colorschemes), the wallust CSS/`theme/` palette, `nwg-displays`,
      and the untracked-file links in the scripts; `.gitignore` deduplicated
- [x] Dropped wlsunset: nothing launched it, Noctalia's `[nightlight]` does the job
      (Omarchy keeps hyprsunset via its own package)

## Next

- [ ] **Re-enable SIP on the MacBook Air.** Partially disabled on 2026-09-01 to
      try yabai (`csrutil enable --without fs --without debug --without nvram`
      plus `sudo nvram boot-args=-arm64e_preview_abi`). yabai never worked —
      its scripting addition cannot inject into Dock.app on Apple Silicon +
      Sequoia (asmvik/yabai #2686, #2747) — so the machine is running with
      reduced security for no benefit. From Recovery: `csrutil enable`, then
      after rebooting `sudo nvram -d boot-args`. Watch meanwhile for broken
      Apple Pay, iPhone Mirroring and DRM'd playback.
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
- [ ] Integrate Omarchy and personal dotfiles more tightly: document ownership boundaries, reduce duplicated Hypr/desktop config, and make install/update behavior clearer across Omarchy, Noctalia, headless, and macOS machines
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
