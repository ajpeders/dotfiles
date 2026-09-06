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

Edit `~/.config/hypr/config/keybinds.lua`. The file already defines `mod` (from
`config.defaults`) and an `ipc` string for Noctalia commands:

```lua
hl.bind(mod .. " + X", hl.dsp.exec_cmd(ipc .. " <target> <function>"))
```

Then reload: `hyprctl reload`

## Fresh install on new machine

```bash
git clone <repo-url> ~/.config
cd ~/.config
bash scripts/install.sh
```

## Update existing install

```bash
cd ~/.config
bash scripts/update.sh
```

## Configure monitors

Edit `hypr/config/monitors.lua` by hand. **Don't use `nwg-displays`** — it writes
connector-keyed rules (`DP-2`, `DP-3`) to `monitors.conf`, which no longer exists. Connector names identify a *port*, not a *panel*, so the same rule means
a different monitor at a different desk.

Two conventions keep one file working on every machine:

- **Match by `desc:`** (EDID make/model), never by connector name. Partial matches
  work, so serials are omitted and a rule matches any unit of that model.
- **Give known panels absolute coordinates**, and let everything else fall
  through to the `auto` catch-all at the top of the file. Relative `auto-*`
  placement was tried and abandoned: `auto-right` measures against the whole
  layout's bounding box, so a panel placed below pushes the right-hand monitor
  clear of it and leaves a hole in the row, and `auto-center-down` centers under
  one neighbour rather than under the row. Absolute coordinates are also
  independent of Hyprland's placement order, which is the monitor *connection*
  order and so isn't knowable from the config.
- **Bottom-align a row of unequal-height panels.** Panels only hand focus to each
  other across exactly aligned edges, so offset the shorter panel's `y` instead of
  starting every panel at `y=0` (the AOC sits at `0x90` so its bottom edge lines
  up with the Samsung's at `y=1440`).

Rules for panels that aren't connected are never matched, so every setup lives in
the same file; an absent panel just leaves its coordinates unused. Unknown
displays fall through to the catch-all rule at the top.

The primary monitor is expressed as a workspace rule in `hypr/hyprland.lua` —
Hyprland has no primary flag, so workspace 1 is pinned to the panel that should
own the session on login (currently the Samsung).

### Adding a new monitor

You can only read a panel's EDID description while it's plugged in. At the new desk:

```bash
~/.config/hypr/scripts/capture-monitor.sh
```

It prints ready-to-paste `hl.monitor()` blocks for everything currently connected.
Paste them into `hypr/config/monitors.lua` and fix up the positions.

### Testing a change without reloading

```bash
hyprctl eval "hl.monitor({ output = 'desc:AOC 2460G4', mode = '1920x1080@144', position = '0x90', scale = 0.8 })"
```

Applies immediately; reverts on the next config reload. Use this to test a mode
before committing to it.

### Gotchas

- **Scale must yield integer logical sizes.** `width / scale` and `height / scale`
  must both be whole numbers or directional focus across monitors breaks.
  `1920 / 0.8 = 2400` is fine; `1920 / 0.83 = 2313.25` is not.
- **EDIDs can under-report the max refresh rate — but a mode lighting up is not
  proof it holds.** The Samsung G53F advertises only 60 Hz in its EDID, so the
  advertised mode list is useless. Forcing 200 Hz link-trains successfully and
  looks perfectly normal on the desktop, then drops frames under load
  (fullscreen games visibly judder). It runs 144 Hz cleanly, which is what the
  config uses. Test a candidate mode **under load**, not just by checking that
  the image appears.

## macOS: mount luna SMB share on login

The share lives on the home server ISIS and is mounted as
`smb://ween@share.thelunadog.com/share`, landing at `/Volumes/share` with a `~/share` symlink.

`share.thelunadog.com` resolves to `192.168.0.176`. That LAN address is reachable from
anywhere on the tailnet because ISIS advertises `192.168.0.0/24` as a subnet route, so the
mount works at home and remotely with no DDNS involved. Public DDNS (`luna-server.ddns.net`)
is a dead end — port 445 is blocked end-to-end.

> **Use `share.thelunadog.com`, never `smb.thelunadog.com`** — see the abandoned migration
> below before changing this hostname.

### One-time setup per macOS machine

```bash
# 1. Seed Keychain with the SMB password (prompts, no plaintext on disk).
#    The server name here MUST match the hostname in the mount URL.
security add-internet-password -a ween -s share.thelunadog.com -r 'smb ' -w

# 2. Symlink the LaunchAgent and load it.
ln -sfn ~/dotfiles/macos/com.alex.mount.share.plist ~/Library/LaunchAgents/com.alex.mount.share.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.alex.mount.share.plist

# 3. Convenience symlink.
ln -s /Volumes/share ~/share
```

The agent runs `macos/mount-share.sh`, which waits for the share to answer on port 445 and
then hands off to `osascript 'mount volume ...'` — Finder pulls the password from Keychain and
creates the mount point itself. Manual trigger:

```bash
launchctl kickstart -k gui/$(id -u)/com.alex.mount.share
```

### The login race

At login the agent fires before Tailscale finishes bringing up the tunnel, so the subnet route
to `192.168.0.176` does not exist yet and the mount fails. The original agent called `osascript`
directly with `RunAtLoad` and no retry, so one early failure meant no share until you mounted it
by hand.

`mount-share.sh` closes this from both ends:

- it polls port 445 for roughly 60s before attempting the mount, and
- it exits non-zero if that never succeeds, so the agent's `KeepAlive`/`SuccessfulExit=false`
  makes launchd retry, throttled to every 5 minutes.

The effect is that the share mounts a few seconds after the tunnel comes up, and a machine
booted off-network mounts itself whenever it reconnects. The script exits 0 immediately when
`/Volumes/share` is already mounted, so the retries are harmless.

### Abandoned: moving to `smb.thelunadog.com` / the tailnet address

A change on 2026-09-01 repointed the mount at ISIS's tailnet address behind a new
`smb.thelunadog.com` name. It silently broke the login mount for four days and was reverted on
2026-09-05. Two preconditions were written down but never actually satisfied on ISIS:

1. `smb.thelunadog.com` must resolve to ISIS's tailnet address (`tailscale ip -4 isis`) — it
   still resolves to `192.168.0.176`.
2. Samba on ISIS must bind the Tailscale interface — port 445 on that address is still closed.

The rename alone is enough to break the mount even when the host is perfectly reachable:
**macOS keys SMB credentials by server name**, so the Keychain entry saved under
`share.thelunadog.com` is not found when mounting `smb.thelunadog.com`. Finder ends up with no
password and, with nobody to prompt at login, the agent dies with AppleScript error `-5014`.

To retry this properly: fix DNS and Samba's bind address on ISIS first, confirm with
`nc -z "$(tailscale ip -4 isis)" 445`, re-seed the Keychain under the new name, and only then change the
mount URL in the plist, `mount-share.sh`, and `macos/install.sh` together.

### Gotchas hit while setting this up

- **AppleScript error `-5014` is misleading.** It reads like a network failure, but the host
  pings fine and 445 is open. It is what you get when Finder has no usable credential — most
  often the Keychain entry's server name not matching the mount hostname.
- **`/mnt` doesn't exist on macOS** — SIP makes the root read-only. Use `/Volumes/<name>`.
- **`mount -t smbfs` fails as a regular user** with `invalid file system`. Use `mount_smbfs` directly instead, which doesn't need sudo.
- **Mount-point ownership matters.** If `/Volumes/share` is owned by root, `mount_smbfs` returns `Operation not permitted`. Fix: `sudo chown $(whoami):staff /Volumes/share` before mounting. Using `osascript 'mount volume ...'` (the LaunchAgent path) sidesteps this — Finder creates the mount point itself.
- **Terminal TCC permissions.** Kitty (and other non-default terminals) need **System Settings → Privacy & Security → Full Disk Access** to read mounted network volumes. Without it, `ls /Volumes/share` returns `Permission denied` even though the mount is up. Restart kitty fully after granting.
- **Public DDNS is a dead end.** `luna-server.ddns.net:445` is blocked by ISP/router; only the LAN address (via the tailnet subnet route) works.

### Uninstall

```bash
launchctl bootout gui/$(id -u)/com.alex.mount.share
rm ~/Library/LaunchAgents/com.alex.mount.share.plist ~/share
```

## Tailscale at login

Handled by `scripts/install.sh` (Arch/Debian) and `macos/install.sh` — nothing to do
by hand on a fresh machine beyond authenticating once.

**Linux:** `tailscale` is in the headless base of `packages.txt`; the installer runs
`systemctl enable tailscaled`. Authenticate once with `sudo tailscale up`.

**macOS:** the `tailscale-app` cask installs the standalone build
(`io.tailscale.ipn.macsys`). That build ships `TailscaleStartOnLogin = 0` and
registers no login item, so startup is driven by a LaunchAgent instead of the GUI
toggle:

```bash
ln -sfn ~/dotfiles/macos/com.alex.tailscale.plist ~/Library/LaunchAgents/com.alex.tailscale.plist
launchctl load ~/Library/LaunchAgents/com.alex.tailscale.plist
```

The agent runs `open -g /Applications/Tailscale.app` at login; the app reconnects the
tunnel from its saved profile. `open` is a no-op when the app is already running, so
the agent is safe to re-trigger (`launchctl start com.alex.tailscale`).

Authenticate a fresh machine with `tailscale up` — `/usr/local/bin/tailscale` is a
shim the app installs, pointing at the binary inside the bundle.

### Gotchas

- Don't mix the `tailscale` **formula** with the `tailscale-app` **cask**: the formula
  drops `/Library/LaunchDaemons/homebrew.mxcl.tailscale.plist`, which fights the app's
  own network extension over the tunnel. If it's left over from an old install:
  `sudo launchctl unload /Library/LaunchDaemons/homebrew.mxcl.tailscale.plist &&
  sudo rm /Library/LaunchDaemons/homebrew.mxcl.tailscale.plist`.
- The standalone build has no `install-system-daemon` subcommand — that's the open
  source `tailscaled`, not this app. Tailscale here is per-login, not per-boot.

## macOS: switch between AeroSpace and yabai

Both window managers are configured in the repo. They must never run at once —
they both drive the Accessibility API and will fight over every window.

**AeroSpace** (`macos/aerospace/`) needs no system changes and is the default.

**yabai** (`macos/yabai/` + `macos/skhd/`) needs SIP partially disabled, because
its scripting addition injects into `Dock.app` to manage spaces and displays.
From Recovery (hold the power button → Options):

```
csrutil enable --without fs --without debug --without nvram
```

then, on Apple Silicon, after rebooting:

```
sudo nvram boot-args=-arm64e_preview_abi
```

Reboot again, quit AeroSpace and remove it from Login Items, then:

```bash
brew bundle --file=macos/Brewfile
bash scripts/setup-yabai.sh
```

That installs the scripting addition, writes a hash-pinned sudoers rule so it
loads without a password, starts both services, and creates the 9 macOS Spaces
the `alt-1..9` bindings expect. Grant Accessibility permission to yabai *and*
skhd when prompted.

**Re-run `scripts/setup-yabai.sh` after every yabai upgrade** — the sudoers rule
pins the binary's SHA-256, so an upgrade invalidates it by design. macOS updates
can also reset SIP.

Going back: `yabai --stop-service && skhd --stop-service`, then re-enable
AeroSpace in Login Items. To restore full SIP, run `csrutil enable` in Recovery
and `sudo nvram -d boot-args`.

Trade-offs worth remembering: yabai uses *real* macOS Spaces rather than
AeroSpace's emulated workspaces, and reduced SIP can break Apple Pay, iPhone
Mirroring and DRM'd playback.
