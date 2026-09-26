# HOWTO

## Update an existing install

```bash
bash ~/.config/scripts/update.sh   # pull, packages, relink, reload
bash ~/.config/scripts/doctor.sh   # read-only check afterwards
```

`update.sh` remembers headless vs full from `~/.local/state/dotfiles-mode`; pass `--full` or `--headless` to override.

**Remotes:** Forgejo is primary and pushes to GitHub too, so a plain `git push` updates both. One-time setup per clone:

```bash
F=$(git remote -v | awk '/thelunadog.*fetch/{print $1; exit}')
git config branch.main.remote $F
git remote set-url --push $F "$(git remote get-url $F)"
git remote set-url --add --push $F git@github.com:ajpeders/dotfiles.git
```

## Migrate off Omarchy

From a TTY or SSH session (step 2 removes the Omarchy desktop):

```bash
git -C ~/.config pull --ff-only forgejo main           # 1. deletes the tracked Omarchy files
sudo pacman -Rns $(pacman -Qq | grep '^omarchy')       # 2. read the list before confirming
grep -n -i omarchy /etc/pacman.conf /etc/pacman.d/*    # 3. remove any repo/key it added
bash ~/.config/scripts/install.sh                      # 4. noctalia, ly, hypridle; sddm -> ly
rm -rf ~/.local/share/omarchy ~/.local/state/omarchy ~/.config/omarchy   # 5. leftovers
```

Reboot, pick **Hyprland** in ly, run `bash scripts/doctor.sh`. Leftovers of the old Omarchy-shell/jetshell experiment are inert and safe to delete: `~/.local/share/omarchy-shell`, `~/.local/bin/omarchy-shell-start`, `~/.local/state/jetshell`.

## Add a Hyprland keybind

Edit `hypr/config/keybinds.lua`; it defines `mod` and an `ipc` string for Noctalia:

```lua
hl.bind(mod .. " + X", hl.dsp.exec_cmd(ipc .. " <command>"))
```

Then `hyprctl reload && hyprctl configerrors` (a reload succeeds even with errors).

## Noctalia

```bash
noctalia msg --help                          # all IPC commands
noctalia msg wallpaper-set ~/Pictures/Wallpapers/image.jpg
noctalia msg color-scheme-set builtin Kanagawa
systemctl --user restart noctalia-shell      # or Super+Shift+R
noctalia config validate
```

Config is `noctalia/config.toml`; anything changed in the settings GUI goes to `~/.local/state/noctalia/settings.toml` and wins. If a value seems ignored, look there.

Theme templates (`builtin_ids`) render `hypr/noctalia.lua`, `kitty/themes/noctalia.conf`, `gtk-{3,4}.0/noctalia.css` and the btop theme, all gitignored.

- Template output directories must already exist; Noctalia won't create them and logs nothing (hence `kitty/themes/.gitkeep`).
- Re-selecting the same scheme doesn't re-render: `noctalia msg templates-apply`.
- Border colours load inside a `pcall`, so a failure shows as default borders, not in `configerrors`.

## Stop the screen locking mid-game or mid-video

hypridle (`hypr/hypridle-{ac,battery}.conf`) locks after 5 min on AC, 2 min on battery. Gamepad input doesn't count as activity, so `hypr/config/windowrules.lua` sets `idle_inhibit = "fullscreen"`: anything fullscreen blocks the lock. For a windowed app, toggle caffeine (`Super+Shift+A`).

```bash
hyprctl clients -j | jq '.[] | select(.fullscreen > 0) | .inhibitingIdle'
systemd-inhibit --list    # caffeine shows as "Caffeine"
```

## Configure monitors

Edit `hypr/config/monitors.lua` by hand (not `nwg-displays`, which writes connector-keyed rules):

- **Match by `desc:`** (EDID make/model), never connector. Add the serial only when two panels share a model.
- **Give known panels absolute coordinates**; everything else hits the `auto` catch-all.
- **Bottom-align rows of unequal height**, since focus only crosses exactly aligned edges.
- Workspace 1 is pinned to the login monitor in `hypr/hyprland.lua` (Hyprland has no primary flag).

To add a panel, plug it in and run `hypr/scripts/capture-monitor.sh`; paste the printed blocks and fix the positions.

`hypr/scripts/livingroom-mode.sh` cycles all monitors → TV only → everything but the TV. For a different TV, capture it and update `TV_DESC` in the script.

Gotchas:

- `width / scale` and `height / scale` must be whole numbers or cross-monitor focus breaks.
- A mode lighting up isn't proof it holds: test refresh rates under load (a fullscreen game), not just on the desktop.

## LLM: opencode and claude-local

Everything defaults to the local Ollama (`qwen3-coder:30b`). Launchers, linked into `~/.local/bin` by the installers:

| Command | Models |
|---|---|
| `opencode` | local; build/plan fall back to the cloud chain in `opencode/plugins/model-fallback.js` on error |
| `opencode-local` | local only, no fallback |
| `opencode-cloud` | every agent on `openai/gpt-5.6-sol` |
| `claude-local` | Claude Code against Ollama; `LLM_MODEL` overrides the model |

To use another server, run `bash scripts/setup-llm.sh <base-url>`. It writes `~/.local/state/dotfiles/llm.env` (shells) and the gitignored `environment.d/90-llm-local.conf` (session), which override the defaults in `environment.d/50-llm.conf` and `zsh/.zshrc`. Session changes apply at next login; to test now:

```bash
systemctl --user set-environment LLM_SERVER_URL=http://host:11434/v1
opencode debug config
```

Keep every agent on one model: the server runs `OLLAMA_NUM_PARALLEL=1`, so a second model means swaps.

Per-project overrides: copy a prompt from `opencode/prompts/` into the project's `.opencode/prompts/`, or add `.opencode/opencode.json`; project-local wins.

### Ollama server setup

The server config in `etc/` is installed by hand:

```bash
sudo install -Dm644 etc/ollama-override.conf /etc/systemd/system/ollama.service.d/override.conf
sudo install -Dm644 etc/ollama-gate.nft /etc/ollama-gate.nft
sudo install -Dm644 etc/ollama-gate.service /etc/systemd/system/ollama-gate.service
sudo systemctl daemon-reload && sudo systemctl enable --now ollama-gate && sudo systemctl restart ollama
```

`ollama-gate` limits port 11434 to LAN, tailnet and docker bridges.

## VPN

Two independent VPNs; helpers live in `zsh/.zshrc`.

| | AmneziaWG | Tailscale |
|---|---|---|
| Routing | full tunnel | tailnet only |
| Up / down | `vpn-up [name]` / `vpn-down [name]` | `ts-up` / `ts-down` |
| Status | `vpn-status`, `vpn-list` | `ts-status` |

**AmneziaWG:** use `awg`/`awg-quick` (`amneziawg-tools`); they handle plain WireGuard configs too, so `wireguard-tools` isn't installed. Configs hold private keys and live untracked in `~/.config/wireguard/` (mode 600); `scripts/sync-private.sh` copies them to a new machine. `vpn-up` defaults to `$VPN_DEFAULT`. Interface names cap at 15 characters and `awg-quick` names them after the file, so rename long wg-easy exports:

```bash
install -Dm600 /dev/stdin ~/.config/wireguard/<short-name>.conf   # paste, Ctrl-D
```

**Tailscale:** the installers enable it at login (Linux: `tailscaled.service`; macOS: the `com.alex.tailscale` LaunchAgent opens the app). Authenticate once with `sudo tailscale up --accept-dns=false`; after that `ts-up` works. `--accept-dns=false` keeps MagicDNS from fighting the WireGuard tunnel over `systemd-resolved`, so use tailnet IPs or FQDNs.

- Don't run two full tunnels at once (WireGuard plus a Tailscale exit node, or two WireGuard configs).
- On macOS, don't mix the `tailscale` formula with the `tailscale-app` cask; the formula's LaunchDaemon fights the app.

## macOS: SMB share on login

`macos/install.sh` seeds the Keychain entry and loads the `com.alex.mount.share` LaunchAgent, which runs `macos/mount-share.sh` at login and every 5 min. Optional: `ln -s /Volumes/share ~/share`. Manual trigger:

```bash
launchctl kickstart -k gui/$(id -u)/com.alex.mount.share
```

- **macOS keys SMB credentials by server name.** The Keychain entry must use the exact hostname in the mount URL, or the mount fails with AppleScript error `-5014`.
- kitty needs **Full Disk Access** to read network volumes; restart it after granting.
- A stale mount (listed but hanging) isn't self-healed: `umount -f /Volumes/share` and let the next run remount.

## Vaultwarden from the CLI (`rbw`)

```bash
rbw list / rbw get <item> / rbw get --full <item> / rbw sync / rbw lock
```

`rbw` unlocks without a prompt: the master password lives in gnome-keyring (unlocked at login through PAM) and `rbw/pinentry-rbw` hands it over. If the lookup fails it falls back to `pinentry-gnome3`.

New machine (`rbw` and `libsecret` installed):

```bash
rbw config set email <email>
rbw config set base_url https://vault.thelunadog.com
rbw config set pinentry pinentry-gnome3        # real pinentry for login, see below
rbw config set lock_timeout 28800
rbw login
secret-tool store --label='Vaultwarden master (rbw)' service vaultwarden account <email>
rbw config set pinentry ~/.config/rbw/pinentry-rbw
rbw stop-agent && rbw get <some-item>          # should not prompt
```

- `rbw login` must not use the shim: it asks for the 2FA code through pinentry too, and the shim answers with the master password.
- Anyone who can log in gets silent vault access; don't do this on a shared machine.

## Neovim LSP

Servers start automatically for Lua, shell, Python, JSON, CSS, TOML and Markdown. `K` docs, `gd` definition, `gr` references, `Space rn` rename, `Space ca` code action, `Space f` format, `Space e` diagnostic. `:checkhealth vim.lsp` to debug.
