# homeserver (isis)

Home-directory dotfiles for the `alex` account on the homelab server — the
files that live in `$HOME` itself, as opposed to the shared `~/.config`
contents this repo already manages.

Captured 2026-08-27. This host runs headless Arch. zsh uses the shared
`zsh/.zshrc` via `ZDOTDIR` like every other machine (the old host `.zshrc` was
never read once `--full` set `ZDOTDIR`).

Install (from the repo root, i.e. `~/.config`):

```sh
bash hosts/homeserver/install.sh          # link the $HOME dotfiles (idempotent)
bash hosts/homeserver/install.sh --full   # + run the main scripts/install.sh --headless
```

Anything replaced that wasn't already a repo symlink is kept as
`<name>.pre-dotfiles` next to the original.

Nothing here is secret (verified before committing): no tokens, hosts, or
addresses — safe for the public mirror.
