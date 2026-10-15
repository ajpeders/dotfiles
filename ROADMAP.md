# Roadmap

## Status

Hyprland is the Linux desktop (Omarchy removed 2026-09-26; Noctalia removed 2026-10-15). The shell is this repo's Quickshell config. Past work is in `git log`.

## Next

- [ ] **DOT-01 — Re-enable SIP on the MacBook Air** (human: needs the MacBook Air in Recovery, 1 pts)
  - **Why:** SIP was partly disabled for yabai, which never worked on Apple Silicon + Sequoia.
  - **Start here:** MacBook Air Recovery mode.
  - **Do:** Boot Recovery, run `csrutil enable`; after reboot, run `sudo nvram -d boot-args`.
  - **Done when:** SIP is fully enabled (verify with `csrutil status` in macOS).
- [ ] **DOT-02 — Capture MacBook Air's built-in panel (eDP-1) into monitors.lua** (human: run on the MacBook Air, 2 pts)
  - **Why:** The Air's built-in panel currently hits the catch-all; it needs a proper entry in `hypr/config/monitors.lua`.
  - **Start here:** `hypr/scripts/capture-monitor.sh`, `hypr/config/monitors.lua`.
  - **Do:** Run `capture-monitor.sh` on the Air to capture eDP-1, add the output to `monitors.lua`.
  - **Done when:** The Air's display is explicitly configured in monitors.lua and Hyprland respects its geometry.
- [ ] **DOT-03 — Test `scripts/install.sh` on a fresh system** (human: needs a fresh machine, 2 pts)
  - **Why:** `install.sh` hasn't been validated on a clean install — it needs a fresh-system smoke test.
  - **Start here:** `scripts/install.sh`, a fresh VM or spare machine.
  - **Do:** Run `install.sh` on a fresh system and verify all dotfiles are installed correctly.
  - **Done when:** A fresh system boots with all dotfiles properly applied.
- [ ] **DOT-04 — Fix link opening in Kitty/OpenCode to use current workspace** (ready, 3 pts)
  - **Why:** Links clicked in Kitty/OpenCode don't open on the current Hyprland workspace. A custom `xdg-mime` handler with `librewolf --new-window` didn't work.
  - **Start here:** `xdg-mime` handler config, Kitty/OpenCode link launch code, Hyprland workspace rules.
  - **Do:** Investigate the launch path and browser window placement; try an alternative handler that opens links in a new window on the current workspace.
  - **Done when:** Clicking a link in Kitty/OpenCode opens it in a new LibreWolf window on the current Hyprland workspace.
- [x] Add Quickshell themes: white, black, or wallpaper-matched colors (switch via `quickshell ipc call theme set <mode>`).

## Quickshell

- [ ] **Dock** — app dock with icons, workspace filtering, hover previews
- [ ] **Notification center** — dunst/notify-desktop integration
- [ ] **Lock screen** — time, password prompt, wake gesture
- [ ] **Media player widget** — MPRIS integration (Spotify, etc.)
- [ ] **Settings popup** — brightness, volume, theme cycling, network, bluetooth
- [ ] **System tray popover** — expandable menus for wifi, audio, battery
- [ ] **Clipboard history** — `Super + V` (was Noctalia's clipboard panel)
- [ ] **Session / power menu** — `Super + O` (lock, logout, reboot, shutdown)
- [ ] **Caffeine toggle** — `Super + Shift + A` / `Super + Ctrl + A` idle inhibitor
- [ ] **Brightness / volume OSD** — on-screen feedback (the keys now drive `brightnessctl` / `wpctl` directly)
- [ ] **Tailscale and DNS widgets** — replaced the removed Noctalia plugins
- [ ] **Render GTK/btop/qt6ct palettes from Quickshell** — only kitty is generated today; the GTK palettes are frozen copies

## Ideas

- Desktop widgets
- Gaming mode toggle (disable shell animations, notifications)
- Last personal bits in the repo: `rbw/config.json` and `rbw/pinentry-rbw` (vault URL, email, absolute pinentry path) plus the rbw HOWTO section. Options: untrack and move to `sync-private.sh`, or template them with a `*.example`.
