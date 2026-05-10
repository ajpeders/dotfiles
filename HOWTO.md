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

Use `nwg-displays` GUI tool. It writes to `~/.config/hypr/monitors.conf` — don't hand-edit that file.

## macOS: mount luna SMB share on login

The share lives on the home server (`192.168.0.176` / `share.thelunadog.com`) and only answers SMB from the LAN or VPN. Public DDNS (`luna-server.ddns.net`) is unreliable — port 445 is blocked end-to-end. Mount lands at `/Volumes/share` with a `~/share` symlink.

### One-time setup per macOS machine

```bash
# 1. Seed Keychain with the SMB password (prompts, no plaintext on disk).
security add-internet-password -a ween -s share.thelunadog.com -r 'smb ' -w

# 2. Symlink the LaunchAgent and load it.
ln -sfn ~/ArchDotfiles/macos/com.alex.mount.share.plist ~/Library/LaunchAgents/com.alex.mount.share.plist
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
