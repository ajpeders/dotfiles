# HOWTO

## Update an existing install

```bash
bash ~/.config/scripts/update.sh   # pull, packages, relink, reload
bash ~/.config/scripts/doctor.sh   # read-only check afterwards
```

`update.sh` remembers headless vs full from `~/.local/state/dotfiles-mode`; pass `--full` or `--headless` to override.

**Remotes:** keep one remote as primary and let it push to a mirror too, so a plain `git push` updates both. One-time setup per clone (`F` = the primary remote's name):

```bash
F=origin
git config branch.main.remote $F
git remote set-url --push $F "$(git remote get-url $F)"
git remote set-url --add --push $F <mirror-url>
```

## Migrate off Omarchy

Run on vega 2026-09-26; the order below is what actually worked. Do it from a
TTY or an SSH session, because step 3 removes the running desktop.

```bash
git -C ~/.config pull --ff-only origin main            # 1. deletes the tracked Omarchy files
sudo pacman -D --asexplicit gnome-keyring              # 2. see below -- do not skip
sudo pacman -Rns omarchy omarchy-settings              # 3. read the list before confirming
bash ~/.config/scripts/install.sh                      # 4. quickshell, ly, hypridle; sddm -> ly
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
`omacalc`, `tensaku`, `ttfx`, `voxtype-bin`. The repos are an aarch64
package source, unrelated to the desktop. If you do drop `[omarchy]`
(`SigLevel = Required`, which is what `omarchy-keyring` signs), it uniquely
serves only four: `hyprland`, `hyprland-guiutils` and `hyprtoolkit` come from
`extra` at the same or newer versions, and `claude-code` from the AUR.
`[omarchy-aarch64]` is `SigLevel = Optional TrustAll` and needs no keyring.

`-Rns` also removes `uwsm`, `sddm`, `plymouth`, `pacman-contrib` and SDDM's X11
greeter stack (`xorg-server`, `xorg-xauth`, `libxmu`, `xf86-input-libinput`).
All expected — `xorg-xwayland` is untouched, so X11 apps still work.

Two `/etc` drop-ins are worth keeping, just renaming: the global DNS pointing at
the home resolver, and the SSH keepalives. Everything else Omarchy put under `/etc` goes with
the packages. Install the Wi-Fi resume replacement afterwards — see "Wi-Fi does
not come back after suspend".

Leftovers of the old Omarchy-shell/jetshell experiment are inert and safe to
delete: `~/.local/share/omarchy-shell`, `~/.local/bin/omarchy-shell-start`,
`~/.local/state/jetshell`.

## Add a Hyprland keybind

Edit `hypr/config/keybinds.lua`; it defines `mod` and the shell IPC command:

```lua
hl.bind(mod .. " + X", hl.dsp.exec_cmd("jetshell ipc call <target> <fn>"))
```

Then `hyprctl reload && hyprctl configerrors` (a reload succeeds even with errors).

## JetShell

The shell (JetShell, a Quickshell config) runs under systemd (`systemd/user/jetshell.service`,
`Restart=on-failure`), started at session start by `hypr/config/autostart.lua`. Manage it with
`systemctl --user`:

```bash
systemctl --user restart jetshell.service     # reload after breaking the QML
systemctl --user stop jetshell.service
systemctl --user start jetshell.service
systemctl --user status jetshell.service
journalctl --user -u jetshell.service -f      # live log
jetshell log                                  # same log, straight from the shell
jetshell list                                 # running instances
```

Quickshell watches its own QML, so edits under `jetshell/` reload live -- restart only
when the config failed to parse. The unit retries forever, so a bad edit crash-loops until
the file is valid again and the shell returns on its own.

The config lives at `~/.config/jetshell/`, which is not where Quickshell looks by default
(`~/.config/quickshell/`), so the path is always passed explicitly -- `--path` in
`systemd/user/jetshell.service`, and `-p` inside the `jetshell` launcher (`scripts/jetshell`,
linked into `~/.local/bin`), which is just `quickshell -p ~/.config/jetshell "$@"`.

Talk to the running shell over IPC. From a terminal, use `jetshell` (`jetshell help`
lists all of it; a bare `jetshell` prints the same instead of starting a second shell):

```bash
jetshell ipc call launcher toggle                    # app launcher
jetshell ipc call notifications toggle               # notification center
jetshell ipc call clipboard toggle                   # clipboard history
jetshell ipc call theme get                          # -> white | black | red
jetshell ipc call theme set black                    # white | black | red
jetshell ipc call theme cycle                        # white -> black -> red (Super+T)
jetshell ipc call theme getWallpaper
jetshell ipc call theme setWallpaper ~/Pictures/Wallpapers/upscaled_maoguin.png
jetshell ipc call metrics get                        # CPU / RAM summary
jetshell ipc call metrics gpu                        # per-GPU VRAM
jetshell list                                        # running instances
jetshell log                                         # shell log
```

Keybinds use `jetshell` too. That only works because `hypr/config/environment.lua` prepends
`~/.local/bin` to Hyprland's own `PATH`, which excludes it by default (login shells add it).
The line is idempotent -- Hyprland re-reads that file on every reload, so it drops any copies
of the entry before re-adding one. Outside the Hyprland session entirely, pass
`-p ~/.config/jetshell` to `quickshell` yourself.

`setWallpaper` takes an absolute path (a `file://` URL works too) and sets the wallpaper
for the *current* theme only: each theme (light, dark, red) keeps its own, so switching
themes switches wallpapers. Choices persist under `~/.local/state/quickshell/` (`wallpapers`). The control center's Theme/Wallpaper
buttons call the same functions. Keybinds live in `hypr/config/keybinds.lua`.

Quickshell renders `kitty/themes/quickshell.conf` on startup and on theme changes (`jetshell/sync-kitty-theme.sh`, driven by `Theme.qml`). The GTK palettes (`gtk-{3,4}.0/quickshell.css`) are frozen copies until Quickshell renders them too -- see ROADMAP.

## Use the clipboard history

`Super + Ctrl + V` opens a picker over the last clipboard entries; type to filter, `Enter`
puts the entry back on the clipboard, `Shift+Delete` drops it, `Esc` closes. Nothing is pasted
for you -- paste with `Super + V` (or plain Ctrl+V) afterwards.

Recording is done by `cliphist`, watched by `systemd/user/cliphist.service`
(`wl-paste --watch cliphist store`; started from `hypr/config/autostart.lua` after the env
import, so it has `WAYLAND_DISPLAY`). The panel (`jetshell/ClipboardPanel.qml`) only reads the
list, so it costs nothing while closed.

```bash
systemctl --user status cliphist.service
cliphist list | head                                  # newest first, "<id>\t<text>"
cliphist decode <id> | wl-copy                        # what the panel runs on Enter
cliphist wipe                                         # clear the whole history
```

History is plaintext, in `~/.cache/cliphist/db` -- anything you copy, passwords and API keys
included, lands there until it ages out or you wipe it. Clear it after pasting a secret:

```bash
cliphist wipe && rm -f ~/.cache/cliphist/db
```

## Switch DNS

Control center → DNS picks LAN (`192.168.0.176`, then the router), Router (DHCP) or Cloudflare. `jetshell/dns.sh` rewrites `ipv4/ipv6.dns` on every active ethernet/wifi NetworkManager connection and runs `nmcli device reapply`, so links stay up. No password needed: polkit allows `settings.modify.system` for the active session. To add a preset, edit the `V4`/`V6` tables in `dns.sh` and `dnsPresets` in `ControlCenter.qml`.

systemd-resolved queries global servers alongside per-link ones, so a global `DNS=` would undercut the switcher. Keep `/etc/systemd/resolved.conf.d/10-lan-dns.conf` to `Domains=` only:

```bash
sudo sed -i '/^DNS=/d' /etc/systemd/resolved.conf.d/10-lan-dns.conf && sudo systemctl restart systemd-resolved
jetshell/dns.sh get; resolvectl dns    # verify
```

## Stop the screen locking mid-game or mid-video

hypridle (`hypr/hypridle-{ac,battery}.conf`) locks after 5 min on AC, 2 min on battery. Gamepad input doesn't count as activity, so `hypr/config/windowrules.lua` sets `idle_inhibit = "fullscreen"`: anything fullscreen blocks the lock. For a windowed app, block idle with `systemd-inhibit` (a caffeine toggle is a ROADMAP item; the old `Super+Shift+A` is gone).

```bash
hyprctl clients -j | jq '.[] | select(.fullscreen > 0) | .inhibitingIdle'
systemd-inhibit --list    # see active inhibitors
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

## Take a screenshot or record the screen

Both are keybinds over two scripts; the scripts are the single place to change behaviour.

| Keys | What |
| --- | --- |
| `Super + P` | Full screen → `~/Pictures/Screenshots/` |
| `Super + Shift + P` | Drag a region → file |
| `Super + Ctrl + P` | Drag a region → clipboard |
| `Super + Shift + S` | Drag a region → `swappy`; the saved file is written back on exit |
| `Super + Shift + R` | Start/stop a screen recording |

`hypr/scripts/screenshot.sh {full|region|copy|annotate}` uses `grim` + `slurp` and notifies on save. Esc during a region grab exits quietly — no error, no notification.

`hypr/scripts/screen-record.sh [toggle|start|stop]` uses `gpu-screen-recorder` (GPU/VAAPI, no CPU hit) to record the **focused monitor** and the default audio output to `~/Videos/Screencasts/`. The pidfile lives in `$XDG_RUNTIME_DIR`; `SIGINT` is its stop-and-save. Override the directory with `RECORD_DIR`. To also capture the mic, add `-a default_input` to the command in the script. `gpu-screen-recorder` also does instant replay (`-r <secs>` + `SIGUSR1`), but that isn't wired to a keybind.

## LLM: opencode

Everything defaults to the local server (`qwen3.6:35b-a3b`). Launchers, linked into `~/.local/bin` by the installers:

| Command | Models |
|---|---|
| `opencode` | local by default, no automatic fallback (shared background service) |
| `opencode-local` | local only, no fallback |
| `opencode-codex` | every agent on `openai/gpt-6-sol`, no fallback |
| `opencode-ds` | every agent on `deepseek/deepseek-flash` (V4.1 Flash), no fallback |
| `opencode-claude` | every agent on `anthropic/claude-opus-5-5` (direct Anthropic), no fallback |
| `opencode-or` | OpenRouter only, no model pinned — pick one with `/models` |
| `opencode-mm` | every agent on `minimax-coding-plan/MiniMax-M3` (MiniMax coding plan), no fallback |
| `opencode-hybrid` | cloud for primary work; local for title, explore, and scout |

Point it at the homelab llm-router (`bash scripts/setup-llm.sh http://<homelab>:8080/v1`), not a single llama-swap host: the router queues and picks whichever machine has the model loaded, so opencode and Hermes don't evict each other's models. `scripts/update.sh` re-checks the configured URL every sync (`setup-llm.sh --check`).

To use another server, run `bash scripts/setup-llm.sh <base-url>`. It writes `~/.local/state/dotfiles/llm.env` (shells) and the gitignored `environment.d/90-llm-local.conf` (session), which override the defaults in `environment.d/50-llm.conf` and `zsh/.zshrc`. Session changes apply at next login; to test now:

```bash
systemctl --user set-environment LLM_SERVER_URL=http://host:11434/v1
opencode debug config
```

Keep every agent on one model: each llama-swap host runs `--parallel 1`, so a second model means swaps.
The launchers use private servers so their model and plugin settings do not leak into the shared service.
Connect the DeepSeek and Anthropic accounts with `/connect` before using their launchers. `opencode-or` needs an OpenRouter account too (`/connect openrouter`, or `OPENROUTER_API_KEY` in the environment); with no model pinned it falls back to the newest available OpenRouter model until you pick one from `/models`.

## LLM: hand work to Hermes

`hq` (linked into `~/.local/bin`) files a task on Hermes's kanban board over ssh, following its `task-intake` skill: project = the current git repo (or `-p`), worker model `qwen3.6:35b-a3b`, commits on a branch without pushing; ntfy alerts are optional.

Copy `scripts/hq.env.example` to `~/.local/state/dotfiles/hq.env` and set the SSH alias and remote workspace. The optional ntfy channel enables alerts; environment variables override this file.

```bash
hq "Backfill tests for the parser"          # from inside the repo
hq -p watcher "Audit the docs" < notes.md   # body from stdin
hq -b "Big refactor" "…"                    # filed blocked; start with `hermes kanban unblock <id>`
hq ls [project]; hq show <id>
```

Rule of thumb: Claude Code for work you're watching, opencode for cheap local edits, `hq` for anything that can run unattended.

Per-project overrides: copy a prompt from `opencode/prompts/` into the project's `.opencode/prompts/`, or add `.opencode/opencode.json`; project-local wins.

### Ollama server setup

The `etc/*.example` files are safe, local-only starting points. Copy them to
per-machine files outside the repo and edit the model path and trusted subnet
rules before installing. Keep Ollama bound to localhost unless the firewall
gate is configured and enabled for that machine. Existing installations need
no change; do not replace a working gate with the default-deny example while
other machines depend on remote access.

```bash
mkdir -p ~/.local/state/dotfiles
cp etc/ollama-override.conf.example ~/.local/state/dotfiles/ollama-override.conf
cp etc/ollama-gate.nft.example ~/.local/state/dotfiles/ollama-gate.nft
# Edit the two copies for this machine, then review them before installing.
sudo install -Dm644 ~/.local/state/dotfiles/ollama-override.conf /etc/systemd/system/ollama.service.d/override.conf
sudo install -Dm644 ~/.local/state/dotfiles/ollama-gate.nft /etc/ollama-gate.nft
sudo install -Dm644 etc/ollama-gate.service /etc/systemd/system/ollama-gate.service
sudo systemctl daemon-reload && sudo systemctl enable --now ollama-gate && sudo systemctl restart ollama
```

`ollama-gate` limits port 11434 to the subnets you explicitly allow.

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

Optional: copy `macos/smb.env.example` to `~/.config/dotfiles/smb.env`, set `SMB_HOST`, `SMB_USER`, and `SMB_SHARE`, then run `macos/install.sh`. The installer seeds the Keychain entry and loads the `com.alex.mount.share` LaunchAgent, which runs `macos/mount-share.sh` at login and every 5 min. Without the config file, no SMB setup runs. Optional: `ln -s /Volumes/<share> ~/share`. Manual trigger:

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
