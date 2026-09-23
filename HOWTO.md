# HOWTO

## Change wallpaper

Noctalia manages wallpapers. Use IPC or the settings window:

```bash
noctalia msg wallpaper-set ~/Pictures/Wallpapers/image.jpg
noctalia msg wallpaper-random
noctalia msg settings-open wallpaper
```

## Noctalia IPC

All Noctalia commands follow: `noctalia msg <command>`

```bash
# List all available commands
noctalia msg --help

# Examples
noctalia msg panel-toggle launcher
noctalia msg volume-up
noctalia msg panel-toggle control-center history
noctalia msg settings-toggle
noctalia msg color-scheme-set builtin Kanagawa
```

## Configure Noctalia

Hand-written config is `noctalia/config.toml` (tracked). Anything changed in the
settings GUI is written to `~/.local/state/noctalia/settings.toml`, which wins
over the file. If a value in `config.toml` seems ignored, look there.
`noctalia config validate` checks the file.

Theme colours reach Hyprland, kitty, GTK and btop through Noctalia's built-in
templates (`builtin_ids`; the GUI list in `settings.toml` wins): they render
`hypr/noctalia.lua`, `kitty/themes/noctalia.conf`, `gtk-{3,4}.0/noctalia.css`
and `btop/themes/noctalia.theme`, all gitignored, on every palette change.

- **Template output directories must already exist.** Noctalia will not create
  them and logs nothing when a write fails — `kitty/themes/` was missing, so
  kitty never got a theme. `kitty/themes/.gitkeep` is tracked for that reason.
- Re-selecting the same scheme does not re-render. Force it with
  `noctalia msg templates-apply`.
- `hyprland.lua` loads the colours inside a `pcall`, so a failure there shows
  up as default borders, not as `hyprctl configerrors`. Check with
  `hyprctl getoption general:col.active_border` and
  `hyprctl eval 'return tostring(pcall(require,"noctalia"))'`.

## Restart Noctalia

```bash
systemctl --user restart noctalia-shell.service   # or SUPER+SHIFT+R
```

## Stop the screen locking mid-game or mid-video

Idle is owned by hypridle (`hypr/hypridle-{ac,battery}.conf`), which locks
after 5 min without keyboard/mouse input. Gamepad input never reaches the
Wayland seat and XWayland games don't speak the idle-inhibit protocol, so
`hypr/config/windowrules.lua` has `idle_inhibit = "fullscreen"` on every
window: anything fullscreen blocks the lock. Check it with:

```bash
hyprctl clients -j | jq '.[] | select(.fullscreen > 0) | .inhibitingIdle'
```

For a windowed app, toggle caffeine instead (`SUPER+SHIFT+A`, or
`noctalia msg caffeine-toggle`); it takes a logind idle inhibitor that
hypridle honours. `systemd-inhibit --list` shows it as `Caffeine`.
## Add a Hyprland keybind

Edit `~/.config/hypr/config/keybinds.lua`. The file already defines `mod` (from
`config.defaults`) and an `ipc` string for Noctalia commands:

```lua
hl.bind(mod .. " + X", hl.dsp.exec_cmd(ipc .. " <command>"))
```

Then reload: `hyprctl reload`

## Fresh install on new machine

```bash
git clone <repo-url> ~/.config
cd ~/.config
bash scripts/install.sh
```

## Update existing install

Automatic: a `dotfiles-autopull` timer (systemd user timer on Linux, LaunchAgent
`com.alex.dotfiles-autopull` on macOS) runs `scripts/autopull.sh` every 15 minutes.
It fast-forwards `main` from **Forgejo** (the primary) over the clone's SSH remote, and falls back to GitHub over HTTPS.
It skips when offline or on another branch, and
refuses (logs, never merges) if local commits or uncommitted edits would conflict.
The installers set it up; to enable it by hand on an existing Linux install:

```bash
systemctl --user daemon-reload && systemctl --user enable --now dotfiles-autopull.timer
journalctl --user -u dotfiles-autopull      # what the last runs did
```

Manual pull any time: `~/.config/scripts/autopull.sh`.

Pulling only moves files. New packages and re-linked configs still need a run of
the installer:

```bash
cd ~/.config
bash scripts/install.sh
```

**Remotes: Forgejo is primary, GitHub is a copy.** On every machine, `main` tracks the Forgejo remote, and that remote pushes to both,
so a plain `git push` updates Forgejo and GitHub together. One-time setup per clone (`F` = the remote pointing at git.thelunadog.com):

```bash
F=$(git remote -v | awk '/thelunadog.*fetch/{print $1; exit}')
git config branch.main.remote $F
git remote set-url --push $F "$(git remote get-url $F)"
git remote set-url --add --push $F git@github.com:ajpeders/dotfiles.git
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

## Point opencode at a different LLM server

Defaults live in `environment.d/50-llm.conf` (session-wide) and `zsh/.zshrc`
(shells), both pointing at the local ollama. To use another host, either run
`bash scripts/setup-llm.sh <base-url>` or set the files manually. The script
writes `~/.local/state/dotfiles/llm.env` for shells and the gitignored
`environment.d/90-llm-local.conf` for app launchers, then updates the current
systemd user environment. Files under `environment.d` are read in name order,
so the higher-numbered machine override wins session-wide.

Changes to `environment.d` apply at next login; to test immediately:

```bash
systemctl --user set-environment LLM_SERVER_URL=http://host:11434/v1
opencode debug config      # check the resolved baseURL
```

## Agents

`opencode/opencode.json` defines eight agents, the Ollama provider, and the `@whisperopencode/push` plugin.

| Agent | Mode | Model | Use |
|---|---|---|---|
| `build` | primary | `openai/gpt-5.5` (cloud, falls back to MiniMax-M3 → DeepSeek v4 Pro) | Default. Full edit + bash. Capped at 50 steps. Bash guards deny force-push, `mkfs`, `dd if=`, fork-bomb; `git push` and `rm -rf` ask first. |
| `plan` | primary | `openai/gpt-5.5` (cloud, same fallback chain as build) | Read-only planning. Tab to switch; use when you want analysis without changes. |
| `general` | subagent | `ollama/qwen3-coder:30b` | Multi-step delegated work. Invoke with `@general`. |
| `explore` | subagent | `ollama/qwen3-coder:30b` | Fast read-only codebase search. Invoke with `@explore`. |
| `scout` | subagent | `ollama/qwen3-coder:30b` | External docs and dependency research; clones into OpenCode's cache. Invoke with `@scout`. |
| `review` | subagent | `ollama/qwen3-coder:30b` | Local code review, read-only. Strong enough for review; keeps data on-machine. |
| `debug` | subagent | `ollama/qwen3.6:27b` | Logs, traces, network diagnostics, coredumps. Bounded bash allowlist (no destructive ops). Invoke with `@debug`. |
| `docs-writer` | subagent | `ollama/qwen3-coder:30b` | READMEs, changelogs, ADRs. Edits prose only; bash denied. Invoke with `@docs-writer`. |

### Routing rationale

- **Cloud for primaries.** Build and plan need the strongest reasoning — coding and architecture reward paying for it. Subagents stay local.
- **Subagent model matters less than variety.** arch-alex has `OLLAMA_NUM_PARALLEL=1`, so a different subagent model causes a swap (~5–15 s load). Keep subagents on the fewest models possible.
- **`glm-4.7-flash is retired (2026-09-19).** On the desktop's ROCm backend it processed prompts ~3x slower than `qwen3-coder:30b` and collapsed at long context. Everything local runs on `qwen3-coder:30b` (28 GB resident, 96k ctx, f16 KV).
- **explore/scout moved off `qwen3:8b-32k` (2026-09-20).** The coder and the 8B can't both fit in 32 GB, so running them side by side made them evict each other (5 swaps in 12 min in the logs). The coder is also faster: it's MoE with ~3B active parameters, 169 vs 102 t/s generation on Vulkan. Nothing uses `qwen3.6:27b` by default any more, so nothing swaps the coder out (`debug` moved 2026-09-22). Benchmarks: `/srv/projects/ollama/bench/results.md`.
- **`claude-local` moved to `qwen3-coder:30b` (2026-09-22).** On 09-20 it stayed on `qwen3.6:27b` because the coder guessed wrong `/home/alex/…` paths in 3/3 runs. The launcher now passes `--append-system-prompt` with `$PWD`; with that, 4/4 sandboxed runs were clean at 34–49 s (vs 144 s for the 27B), and there's no model swap. To go back: `LLM_MODEL=qwen3.6:27b claude-local`. opencode `debug` moved the same day: a "start in the working directory" step in `prompts/debug.txt` took it from 0/3 to 3/3 on a sandboxed root-cause test (8–18 s vs 35–47 s on the 27B).
- **review → local coding model.** Even though review is invoked often during build cycles, `qwen3-coder:30b` is purpose-built for code understanding and avoids per-review cloud cost.

### Config layering

1. `~/.config/opencode/opencode.json` — global, tracked, agents, providers, and plugins.
2. `~/.config/opencode/prompts/*.txt` — global prompt bodies.
3. `~/.config/opencode/themes/omarchy.json` — global theme matching the active matugen palette.
4. `~/.config/opencode/tui.json` — sets `theme: omarchy`.
5. `~/.config/opencode/.opencode/` — **templates**. Copy `prompts/*.txt` into a project's `.opencode/prompts/` to override locally; same for `themes/`.
6. `<project>/.opencode/opencode.json` — per-project overrides.

### Prompt templates

`prompts/` holds build, plan, debug, and docs-writer. `.opencode/prompts/` is a mirror for distribution — copy from there into a project's `.opencode/prompts/` and specialize.

### Theme

`themes/omarchy.json` was derived from `~/.local/state/omarchy/current/theme/colors.toml`. If you change themes (`omarchy theme set <name>`), regenerate the JSON with the new palette or pick a built-in via `:theme` in the TUI.

## Boot loader (Limine, desktop only)

The desktop boots Limine, not GRUB. Nothing here is tracked in the repo —
`/boot` lives outside `~/.config` and the config is machine-specific — so this
is the reference for what exists on disk.

| Path | What |
|---|---|
| `/boot/EFI/BOOT/BOOTX64.EFI` | Limine itself, at the *removable* path (inherited from GRUB, so no NVRAM entry was created) |
| `/boot/limine.conf` | hand-written menu; nothing generates it |
| `/boot/limine-bg.png` | menu wallpaper |
| `/etc/pacman.d/hooks/95-limine-efi.hook` | re-copies the EFI binary on `limine` upgrades |

Edit `/boot/limine.conf` directly; it is read fresh at every boot, so there is
no install or regeneration step. `/boot` is mounted `umask=0077`, so you need
`sudo` even to read it.

```bash
sudo nano /boot/limine.conf     # timeout, entries, wallpaper
```

Option reference ships with the package: `/usr/share/doc/limine/CONFIG.md`.

### Adding a kernel entry

Entries are literal — microcode must come *before* the initramfs, because the
Linux boot protocol concatenates modules into one initrd stream and the kernel
reads the early microcode blob off the front:

```
/Arch Linux (zen)
    protocol: linux
    path: boot():/vmlinuz-linux-zen
    cmdline: root=UUID=<root-uuid> rw loglevel=3 quiet
    module_path: boot():/amd-ucode.img
    module_path: boot():/initramfs-linux-zen.img
```

`boot():/` means the volume Limine booted from — here the ESP, which *is*
`/boot`. Other volumes are addressed by GPT partition GUID, e.g. the Windows
chainload entry uses `guid(<esp-partition-guid>):/EFI/Microsoft/Boot/bootmgfw.efi`.

### Gotchas

- **There is no fallback.** GRUB is off the ESP and `/boot/grub` is deleted, so
  a broken Limine means a USB stick. This is why both `linux-zen` and stock
  `linux` stay installed — the second entry is the only in-place recovery.
- The `grub` package is still installed, but only because `woeusb-ng` depends
  on it. It cannot boot anything.
- Limine has **`S Firmware Setup`** built into its menu; don't add an
  `efi_boot_entry` stanza for it (`entry` takes an NVRAM entry *name*).
- A missing wallpaper or font is skipped silently rather than failing the boot;
  a missing kernel path panics.
- Test config changes without rebooting by booting a copy of the ESP under
  OVMF: `qemu-system-x86_64 -drive if=pflash,...OVMF_CODE.4m.fd ...`. Attach a
  display backend (`-vnc`) — with `-display none` the framebuffer never
  refreshes and `screendump` silently returns a black frame.

## VPN

Two independent VPNs. AmneziaWG is never enabled at boot; `tailscaled.service` is enabled by the installer but the tailnet stays down until `ts-up`. Helpers live in `zsh/.zshrc`.

| | AmneziaWG (home server) | Tailscale |
|---|---|---|
| Reaches | wg-easy on the home server | any machine on the tailnet |
| Routing | full-tunnel (`0.0.0.0/0`, `::/0`) | tailnet only (`100.64.0.0/10`) |
| Up / down | `vpn-up [name]` / `vpn-down [name]` | `ts-up` / `ts-down` |
| Status | `vpn-status` | `ts-status` |

### WireGuard / AmneziaWG

We use AmneziaWG through `amneziawg-tools`. On aarch64/Asahi, the userspace
`amneziawg-go` backend may need to stay manually pinned: the current AUR
PKGBUILD rejects `aarch64`, so it is intentionally not synced from
`packages.txt`. `awg-quick` handles both obfuscated and plain WireGuard configs
— with no `Jc`/`S1`/`S2`/`H1..H4` keys present it falls back to standard
WireGuard framing — so `wireguard-tools` is not installed and `wg`/`wg-quick`
are unavailable. Use `awg`/`awg-quick`.

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
- If `tailscale status` says it can't reach the daemon, `tailscaled.service` isn't running (older installs didn't enable it). `ts-up` starts it before connecting.
- **MTU.** The tunnel is pinned to 1420. Tailscale inside the WireGuard tunnel means double encapsulation; if TCP stalls on large transfers while both are up, that's the first thing to suspect.

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

- it polls port 445 for roughly 60s before attempting the mount, so the usual case is covered
  within one run of the agent, and
- the agent re-runs it every 5 minutes (`StartInterval`), so anything slower than that is
  covered too.

The effect is that the share mounts a few seconds after the tunnel comes up, and a machine
booted off-network mounts itself whenever it reconnects. The script exits 0 immediately when
`/Volumes/share` is already mounted, so the re-runs are almost free.

The interval matters beyond login: an earlier version used `KeepAlive` with
`SuccessfulExit=false`, which retries a *failing* job but stops the moment one succeeds. That
covered the login race and nothing else — a share dropped mid-session by sleep or a tunnel blip
stayed gone until the next login, because launchd considered the job done.

**Known gap:** a *stale* mount — the entry still listed by `mount` while I/O hangs — is not
self-healed, since the already-mounted check believes it. macOS usually tears these down on its
own; if it does not, `umount -f /Volumes/share` and let the next run remount.

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


## Vaultwarden from the CLI (`rbw`)

`rbw` gives terminal access to the Vaultwarden server at `https://vault.thelunadog.com`.
It unlocks silently — no master-password prompt — because the master password lives in
the GNOME keyring and a shim hands it to `rbw` on demand.

```bash
rbw list                 # item names
rbw get <item>           # password to stdout
rbw get --full <item>    # username, password, notes
rbw sync                 # refresh from the server
rbw lock                 # drop the cached key
```

### How the unlock chain works

Nothing here talks to the Secret Service API directly — `rbw` only knows how to shell
out to a pinentry program, and that indirection is the whole hook:

1. Your login password unlocks gnome-keyring (`pam_gnome_keyring.so` in `/etc/pam.d/ly`).
2. `rbw` needs the master password and runs `rbw/pinentry-rbw`.
3. The shim speaks the Assuan pinentry protocol and answers `GETPIN` with
   `secret-tool lookup service vaultwarden account <email>`.
4. `rbw-agent` derives the vault key and caches it for `lock_timeout` (8h).

If the keyring is locked or the secret is missing, the shim `exec`s `pinentry-gnome3`
instead, so a broken lookup degrades to a normal prompt rather than a hard failure.

Files: `rbw/config.json` (email, `base_url`, pinentry path, `lock_timeout`) and
`rbw/pinentry-rbw`. Both are tracked. The vault database is **not** — it lives at
`~/.local/share/rbw/`, outside this repo.

### Setting it up on a new machine

```bash
# 1. Point rbw at the server, but use the REAL pinentry for now (see Gotchas).
rbw config set email <email>
rbw config set base_url https://vault.thelunadog.com
rbw config set pinentry pinentry-gnome3
rbw config set lock_timeout 28800

# 2. Log in. Prompts for the master password, and 2FA if enabled.
rbw login

# 3. Seed the keyring (prompts once, nothing in plaintext on disk).
secret-tool store --label='Vaultwarden master (rbw)' service vaultwarden account <email>

# 4. Switch to the shim.
rbw config set pinentry ~/.config/rbw/pinentry-rbw
rbw stop-agent && rbw get <some-item>   # should not prompt
```

### Gotchas

- **`rbw login` must not use the shim.** `rbw` asks for the 2FA code through pinentry
  too, and the shim answers every `GETPIN` with the master password — so login fails in
  a confusing way. Swap to `pinentry-gnome3` for the login, swap back after.
- **`.gitignore` is deny-by-default here.** `rbw/config.json` and `rbw/pinentry-rbw` are
  allowlisted by exact filename, not as `rbw/**`, so anything else `rbw` drops in that
  directory stays untracked. Add new files deliberately.
- **This trades vault security for login security.** Anyone who can log into the desktop
  has silent access to the whole vault. That's the point of the setup, but it means the
  login password is now the only thing guarding it — don't do this on a shared machine.
- `rbw` is the unofficial Rust client (`extra/rbw`), not Bitwarden's `bw`. It keeps a
  local encrypted copy and a background agent, so it's fast enough for scripts; `bw` is
  Node and needs a `BW_SESSION` env var juggled by hand.
