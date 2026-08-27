# livingroom-pi

Home-directory dotfiles for `alex` on the living-room Pi 5 (Debian 13,
bash — deliberately off the homelab; it runs the Apple TV / CEC stack from
the `smarthome` repo). Captured 2026-08-27; near-stock Debian bashrc plus a
`~/.local/bin` PATH entry, no secrets (verified).

Install (from the repo root, i.e. `~/.config` — clone there first):

```sh
bash hosts/livingroom-pi/install.sh
```

Links only: the repo's main `install.sh` is Arch-specific and doesn't apply on
Debian, so there is no `--full` mode here. Replaced files are kept as
`<name>.pre-dotfiles`.
