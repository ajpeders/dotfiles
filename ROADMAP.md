# Roadmap

## Status

Hyprland + Noctalia 5 is the only Linux stack (Omarchy removed 2026-09-26). Past work is in `git log`.

## Next

- [ ] **Re-enable SIP on the MacBook Air.** It was partly disabled for yabai, which never worked on Apple Silicon + Sequoia. From Recovery: `csrutil enable`; after reboot, `sudo nvram -d boot-args`.
- [ ] Capture the Air's built-in panel (`eDP-1`) into `hypr/config/monitors.lua` with `hypr/scripts/capture-monitor.sh`; until then it hits the catch-all
- [ ] Test `scripts/install.sh` on a fresh system
- [ ] Open links clicked in Kitty/OpenCode in a new default-browser window on the current Hyprland workspace. A custom `xdg-mime` handler invoking `librewolf --new-window` did not work; investigate the launch path and browser window placement before trying another handler.

## Ideas

- Desktop widgets via Noctalia
- Gaming mode toggle (disable shell animations, notifications)
- Finish de-personalising the repo: `rbw/config.json` (vault URL, email), the VPN notes in `zsh/.zshrc`, and the Forgejo remote lookup in HOWTO. Noctalia has no env interpolation, but merges every `*.toml` in its dir for per-machine overrides.
- Upstream a `[[shortcut]]` to `nightwatch75/dns-switcher`, then drop `noctalia/plugins/home-tiles`
