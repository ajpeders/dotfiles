# Roadmap

## Current Status

Desktop shell is moving from the older Noctalia stack to Omarchy-managed Hyprland with personal dotfile overrides layered on top.

## Done

- [x] Hyprland base config (workspaces, keybinds, window rules)
- [x] Kitty terminal + Zsh/P10k shell
- [x] Noctalia shell (replaced waybar + rofi + swaync)
- [x] Keybinds updated for Noctalia IPC
- [x] Install/update scripts updated
- [x] Stale waybar/rofi/swaync/quickshell references cleaned up

## Next

- [ ] Integrate Omarchy and personal dotfiles more tightly: document ownership boundaries, reduce duplicated Hypr/desktop config, and make install/update behavior clearer across Omarchy, Noctalia, headless, and macOS machines
- [ ] Test install.sh on a fresh system
- [ ] Review wlsunset — Noctalia has built-in night light, may be redundant

## Ideas

- Desktop widgets via Noctalia
- Gaming mode toggle (disable shell animations, notifications)
