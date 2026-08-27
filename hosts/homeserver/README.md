# homeserver (isis)

Home-directory dotfiles for the `alex` account on the homelab server — the
files that live in `$HOME` itself, as opposed to the shared `~/.config`
contents this repo already manages.

Captured 2026-08-27. This host runs headless Arch; the shell setup is
oh-my-zsh + powerlevel10k, same as the other machines, but kept as its own
profile because the server accumulates host-specific aliases and PATH entries
that shouldn't follow to laptops.

Install (from the repo root, i.e. `~/.config`):

```sh
ln -sfn "$PWD/hosts/homeserver/.zshrc"     ~/.zshrc
ln -sfn "$PWD/hosts/homeserver/.gitconfig" ~/.gitconfig
ln -sfn "$PWD/hosts/homeserver/.bashrc"    ~/.bashrc
```

Nothing here is secret (verified before committing): no tokens, hosts, or
addresses — safe for the public mirror.
