# HOWTO

## Change wallpaper

Noctalia manages wallpapers. Use IPC or the settings panel:

```bash
qs -c noctalia-shell ipc call wallpaper set ~/Pictures/Wallpapers/image.jpg ""
qs -c noctalia-shell ipc call wallpaper random ""
qs -c noctalia-shell ipc call settings openTab wallpaper
```

## Noctalia IPC

All Noctalia commands follow: `qs -c noctalia-shell ipc call <target> <function>`

```bash
# List all available commands
qs -c noctalia-shell ipc show

# Examples
qs -c noctalia-shell ipc call launcher toggle
qs -c noctalia-shell ipc call volume increase
qs -c noctalia-shell ipc call notifications toggleHistory
qs -c noctalia-shell ipc call settings toggle
qs -c noctalia-shell ipc call colorScheme set Kanagawa
```

## Restart Noctalia

```bash
pkill quickshell; qs -c noctalia-shell &
```

## Add a Hyprland keybind

Edit `~/.config/hypr/config/keybinds.conf`. Use `$ipc` variable for Noctalia commands:

```
bind = $mainMod, X, exec, $ipc <target> <function>
```

Then reload: `hyprctl reload`

## Fresh install on new machine

```bash
git clone <repo-url> ~/.config
cd ~/.config
bash install.sh
```

## Update existing install

```bash
cd ~/.config
bash update.sh
```

## OpenCode local remote model

The shared OpenCode config lives in `~/.config/opencode/opencode.json`. It uses
the `local/coder` model through an OpenAI-compatible endpoint at
`http://127.0.0.1:11434/v1`.

For a model served from another machine, change
`providers.local.settings.baseURL` to the host's reachable LAN or Tailscale URL,
for example `http://100.x.y.z:11434/v1`. Keep API keys out of the repo; use
OpenCode auth or an env-backed `apiKey` setting if the endpoint requires one.

## Configure monitors

Use `nwg-displays` GUI tool. It writes to `~/.config/hypr/monitors.conf` — don't hand-edit that file.

## VPN

Two independent VPNs. **Neither is enabled at boot** — start whichever you need. Helpers live in `zsh/.zshrc`.

| | AmneziaWG (home server) | Tailscale |
|---|---|---|
| Reaches | wg-easy on the home server | any machine on the tailnet |
| Routing | full-tunnel (`0.0.0.0/0`, `::/0`) | tailnet only (`100.64.0.0/10`) |
| Up / down | `vpn-up [name]` / `vpn-down [name]` | `ts-up` / `ts-down` |
| Status | `vpn-status` | `ts-status` |

### WireGuard / AmneziaWG

We use the userspace `amneziawg-go` rather than a DKMS kernel module, because out-of-tree modules are fragile on the Asahi kernel. `awg-quick` handles both obfuscated and plain WireGuard configs — with no `Jc`/`S1`/`S2`/`H1..H4` keys present it falls back to standard WireGuard framing — so `wireguard-tools` is not installed and `wg`/`wg-quick` are unavailable. Use `awg`/`awg-quick`.

Client configs are **not in this repo** (they hold private keys). They live in `~/.config/wireguard/`, mode `600`, covered by the catch-all ignore in `.gitignore`. `vpn-list` shows what's available:

| Config | Address | Issued | Obfuscation |
|---|---|---|---|
| `alex` | `10.8.0.2` | 2026-07-04 | AmneziaWG (all 9 params) |
| `isis` | `10.8.0.16` | 2026-08-20 | none — plain WireGuard |

Both point at the same server (`vpn.thelunadog.com:51820`, same peer public key); they're separate client slots with different preshared keys. `vpn-up` defaults to `$VPN_DEFAULT` (currently `alex`); pass a name to override:

```bash
vpn-up isis
```

**`awg-quick` names the interface after the filename, and Linux caps interface names at 15 characters.** wg-easy exports long names like `isis_alex_macm1_20260820.conf` (24 chars) which fail to come up — rename on install:

```bash
install -Dm600 /dev/stdin ~/.config/wireguard/<short-name>.conf   # paste, then Ctrl-D
vpn-up <short-name>
```

### Tailscale

First-time login on a machine (needs a browser for SSO — the URL is printed if you're headless):

```bash
sudo systemctl start tailscaled
sudo tailscale up --accept-dns=false
```

After that, `ts-up` does both steps. `--accept-dns=false` is deliberate: Tailscale's MagicDNS and the AmneziaWG tunnel both want to own `systemd-resolved`, and whichever came up last would win. The cost is that MagicDNS short names don't resolve — use tailnet IPs or fully-qualified names. Drop the flag if you stop using the WireGuard tunnel.

To route all traffic through a tailnet exit node instead: `ts-up --exit-node=<host>`.

### Gotchas

- **Don't run both full-tunnel at once.** The WireGuard tunnel already takes `0.0.0.0/0`; adding a Tailscale exit node on top means two competing default routes. Pick one. The same goes for two WireGuard configs — `vpn-down` the current one before bringing another up.
- **`isis` is unverified.** It carries no obfuscation params, but the server was set up with AmneziaWG obfuscation specifically because plain WireGuard couldn't handshake. If `vpn-up isis` shows no handshake in `vpn-status`, the server hasn't been switched to plain WireGuard and `alex` is still the working config.
- **Tailscale is not enabled at boot**, so `tailscale status` on a fresh boot reports that it can't reach the daemon. That's expected — run `ts-up`.
- **MTU.** The tunnel is pinned to 1420. Tailscale inside the WireGuard tunnel means double encapsulation; if TCP stalls on large transfers while both are up, that's the first thing to suspect.

## macOS: mount luna SMB share on login

The share lives on the home server (`192.168.0.176` / `share.thelunadog.com`) and only answers SMB from the LAN or VPN. Public DDNS (`luna-server.ddns.net`) is unreliable — port 445 is blocked end-to-end. Mount lands at `/Volumes/share` with a `~/share` symlink.

### One-time setup per macOS machine

```bash
# 1. Seed Keychain with the SMB password (prompts, no plaintext on disk).
security add-internet-password -a ween -s share.thelunadog.com -r 'smb ' -w

# 2. Symlink the LaunchAgent and load it.
ln -sfn ~/dotfiles/macos/com.alex.mount.share.plist ~/Library/LaunchAgents/com.alex.mount.share.plist
launchctl load ~/Library/LaunchAgents/com.alex.mount.share.plist

# 3. Convenience symlink.
ln -s /Volumes/share ~/share
```

The LaunchAgent runs `osascript 'mount volume "smb://ween@share.thelunadog.com/share"'` at login — Finder pulls the password from Keychain. Manual trigger: `launchctl start com.alex.mount.share`.

### Gotchas hit while setting this up

- **`/mnt` doesn't exist on macOS** — SIP makes the root read-only. Use `/Volumes/<name>`.
- **`mount -t smbfs` fails as a regular user** with `invalid file system`. Use `mount_smbfs` directly instead, which doesn't need sudo.
- **Mount-point ownership matters.** If `/Volumes/share` is owned by root, `mount_smbfs` returns `Operation not permitted`. Fix: `sudo chown $(whoami):staff /Volumes/share` before mounting. Using `osascript 'mount volume ...'` (the LaunchAgent path) sidesteps this — Finder creates the mount point itself.
- **Terminal TCC permissions.** Kitty (and other non-default terminals) need **System Settings → Privacy & Security → Full Disk Access** to read mounted network volumes. Without it, `ls /Volumes/share` returns `Permission denied` even though the mount is up. Restart kitty fully after granting.
- **Public DDNS is a dead end.** `luna-server.ddns.net:445` is blocked by ISP/router; only LAN IP or VPN works. The plist uses the wildcard rewrite hostname which resolves correctly when on-VPN.

### Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.alex.mount.share.plist
rm ~/Library/LaunchAgents/com.alex.mount.share.plist ~/share
```
