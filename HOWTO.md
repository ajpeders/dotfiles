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

Run on vega 2026-09-26; the order below is what actually worked. Do it from a
TTY or an SSH session, because step 3 removes the running desktop.

```bash
git -C ~/.config pull --ff-only origin main            # 1. deletes the tracked Omarchy files
sudo pacman -D --asexplicit gnome-keyring              # 2. see below -- do not skip
sudo pacman -Rns omarchy omarchy-settings              # 3. read the list before confirming
bash ~/.config/scripts/install.sh                      # 4. noctalia, ly, hypridle; sddm -> ly
rm -rf ~/.local/share/omarchy ~/.local/state/omarchy ~/.config/omarchy   # 5. leftovers
sudo systemctl disable omarchy-wifi-resume-fix.service                   # 6. its script is gone
sudo rm -f /etc/systemd/system/omarchy-wifi-resume-fix.service
```

Reboot, pick **Hyprland** in ly, run `bash scripts/doctor.sh`.

**Step 2 is the one that bites.** `gnome-keyring` is only a dependency of
`omarchy`, so `-Rns` takes it — along with `gcr` — and then `hypr/config/autostart.lua`
cannot start `gnome-keyring-daemon.socket` and `~/.local/share/keyrings` goes
unread. Marking it explicit first is what keeps it. Use `pacman -D --asexplicit`,
not `pacman -S --needed --asexplicit`: `--needed` skips an already-installed
package and the `--asexplicit` remark never happens.

**Keep `omarchy-keyring` and both pacman repos.** 26 installed packages exist
only in `[omarchy]` / `[omarchy-aarch64]` — `claude-code`, `yay`, `obs-studio`,
`obsidian-appimage`, `dotnet-runtime-2.1`, `libva-v4l2_request-avd` (hardware
video decode), `mise-bin`, plus `aether`, `herdr`, `omacut`, `omawrite`,
`omacalc`, `tensaku`, `ttfx`, `voxtype-bin`, `cliamp`. The repos are an aarch64
package source, unrelated to the desktop. If you do drop `[omarchy]`
(`SigLevel = Required`, which is what `omarchy-keyring` signs), it uniquely
serves only four: `hyprland`, `hyprland-guiutils` and `hyprtoolkit` come from
`extra` at the same or newer versions, and `claude-code` from the AUR.
`[omarchy-aarch64]` is `SigLevel = Optional TrustAll` and needs no keyring.

`-Rns` also removes `uwsm`, `sddm`, `plymouth`, `pacman-contrib` and SDDM's X11
greeter stack (`xorg-server`, `xorg-xauth`, `libxmu`, `xf86-input-libinput`).
All expected — `xorg-xwayland` is untouched, so X11 apps still work.

Two `/etc` drop-ins are worth keeping, just renaming: the global DNS pointing at
isis, and the SSH keepalives. Everything else Omarchy put under `/etc` goes with
the packages. Install the Wi-Fi resume replacement afterwards — see "Wi-Fi does
not come back after suspend".

Leftovers of the old Omarchy-shell/jetshell experiment are inert and safe to
delete: `~/.local/share/omarchy-shell`, `~/.local/bin/omarchy-shell-start`,
`~/.local/state/jetshell`.

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

## LLM: opencode

Everything defaults to the local server (`qwen3.6:35b-a3b`). Launchers, linked into `~/.local/bin` by the installers:

| Command | Models |
|---|---|
| `opencode` | local by default, no automatic fallback (shared background service) |
| `opencode-local` | local only, no fallback |
| `opencode-cloud` | every agent on `openai/gpt-6-sol`, no fallback |
| `opencode-hybrid` | cloud for primary work; local for title, explore, and scout |
Point it at the homelab llm-router (`bash scripts/setup-llm.sh http://<homelab>:8080/v1`), not a single llama-swap host: the router queues and picks whichever machine has the model loaded, so opencode and Hermes don't evict each other's models. `scripts/update.sh` re-checks the configured URL every sync (`setup-llm.sh --check`).

To use another server, run `bash scripts/setup-llm.sh <base-url>`. It writes `~/.local/state/dotfiles/llm.env` (shells) and the gitignored `environment.d/90-llm-local.conf` (session), which override the defaults in `environment.d/50-llm.conf` and `zsh/.zshrc`. Session changes apply at next login; to test now:

```bash
systemctl --user set-environment LLM_SERVER_URL=http://host:11434/v1
opencode debug config
```

Keep every agent on one model: each llama-swap host runs `--parallel 1`, so a second model means swaps.
The launchers use private servers so their model and plugin settings do not leak into the shared service.

## LLM: hand work to Hermes

`hq` (linked into `~/.local/bin`) files a task on Hermes's kanban board over ssh, following its `task-intake` skill: project = the current git repo (or `-p`), worker model `qwen3.6:35b-a3b`, commits on a branch without pushing, alerts on ntfy.

```bash
hq "Backfill tests for the parser"          # from inside the repo
hq -p watcher "Audit the docs" < notes.md   # body from stdin
hq -b "Big refactor" "…"                    # filed blocked; start with `hermes kanban unblock <id>`
hq ls [project]; hq show <id>
```

Rule of thumb: Claude Code for work you're watching, opencode for cheap local edits, `hq` for anything that can run unattended.

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

## Wi-Fi does not come back after suspend

The Broadcom chip (`brcmfmac` + `brcmfmac_wcc`) sometimes fails to reassociate
after resume: `wlan0` is still listed but never reconnects. Reloading the driver
recovers it, so a oneshot unit does that on every resume when NetworkManager has
not reconnected within 20s. Installed by hand:

```bash
sudo install -Dm755 etc/wifi-resume-fix /usr/local/bin/wifi-resume-fix
sudo install -Dm644 etc/wifi-resume-fix.service /etc/systemd/system/wifi-resume-fix.service
sudo systemctl daemon-reload && sudo systemctl enable wifi-resume-fix.service
```

Check it fired with `journalctl -t wifi-resume-fix`. This replaces Omarchy's
`omarchy-wifi-resume-fix`, whose unit stayed enabled after the package was
removed on 2026-09-26 while its `ExecStart` no longer existed -- so every
suspend failed a unit and nothing fixed the Wi-Fi.

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
