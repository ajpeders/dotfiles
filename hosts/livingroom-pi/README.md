# livingroom-pi

Home-directory dotfiles for `alex` on the living-room Pi 5 (Debian 13,
bash — deliberately off the homelab; it runs the Apple TV / CEC stack from
the `smarthome` repo). Captured 2026-08-27; near-stock Debian bashrc plus a
`~/.local/bin` PATH entry, no secrets (verified).

Install (from the repo root, i.e. `~/.config` — clone there first):

```sh
bash hosts/livingroom-pi/install.sh          # link the $HOME dotfiles (idempotent)
bash hosts/livingroom-pi/install.sh --full   # + run the repo's Debian bootstrap
```

Links only by default: the repo's main `install.sh` is Arch-specific and
doesn't apply on Debian. `--full` hands off to `install-debian.sh`, which
`apt`-installs the CLI base and sets up zsh + oh-my-zsh + powerlevel10k (no GUI,
ever). Replaced files are kept as `<name>.pre-dotfiles`.
