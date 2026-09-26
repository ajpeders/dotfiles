# Roadmap

## Status

Hyprland + Noctalia 5 is the only Linux stack (Omarchy removed 2026-09-26). Past work is in `git log`.

## Next

- [ ] **Convert the M1 Air from Omarchy to Noctalia** — HOWTO → "Migrate off Omarchy", then `bash scripts/doctor.sh`
- [ ] **Re-enable SIP on the MacBook Air.** It was partly disabled for yabai, which never worked on Apple Silicon + Sequoia. From Recovery: `csrutil enable`; after reboot, `sudo nvram -d boot-args`.
- [ ] Capture the Air's built-in panel (`eDP-1`) into `hypr/config/monitors.lua` with `hypr/scripts/capture-monitor.sh`, once it runs Noctalia; until then it hits the catch-all
- [ ] Test `scripts/install.sh` on a fresh system

## Ideas

- Desktop widgets via Noctalia
- Gaming mode toggle (disable shell animations, notifications)
- Make the repo usable by others: replace homelab-specific hostnames, addresses and paths with env-driven config plus examples
