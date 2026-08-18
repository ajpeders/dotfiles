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

## Configure monitors

Edit `hypr/config/monitors.lua` by hand. **Don't use `nwg-displays`** — it writes
connector-keyed rules (`DP-2`, `DP-3`) to `monitors.conf`, which nothing reads
anymore. Connector names identify a *port*, not a *panel*, so the same rule means
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
