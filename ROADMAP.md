# Roadmap

## Status

Hyprland is the Linux desktop (Omarchy removed 2026-09-26; Noctalia removed 2026-10-15). The shell is JetShell, this repo's Quickshell config. Past work is in `git log`.

## Next

- [ ] **DOT-01 — Re-enable SIP on the MacBook Air** (human: needs the MacBook Air in Recovery, 1 pts)
  - **Why:** SIP was partly disabled for yabai, which never worked on Apple Silicon + Sequoia.
  - **Start here:** MacBook Air Recovery mode.
  - **Do:** Boot Recovery, run `csrutil enable`; after reboot, run `sudo nvram -d boot-args`.
  - **Done when:** SIP is fully enabled (verify with `csrutil status` in macOS).
- [ ] **DOT-02 — Capture MacBook Air's built-in panel (eDP-1) into monitors.lua** (human: run on the MacBook Air, 2 pts)
  - **Why:** The Air's built-in panel currently hits the catch-all; it needs a proper entry in `hypr/config/monitors.lua`.
  - **Start here:** `hypr/scripts/capture-monitor.sh`, `hypr/config/monitors.lua`.
  - **Do:** Run `capture-monitor.sh` on the Air to capture eDP-1, add the output to `monitors.lua`.
  - **Done when:** The Air's display is explicitly configured in monitors.lua and Hyprland respects its geometry.
- [ ] **DOT-03 — Test `scripts/install.sh` on a fresh system** (human: needs a fresh machine, 2 pts)
  - **Why:** `install.sh` hasn't been validated on a clean install — it needs a fresh-system smoke test.
  - **Start here:** `scripts/install.sh`, a fresh VM or spare machine.
  - **Do:** Run `install.sh` on a fresh system and verify all dotfiles are installed correctly.
  - **Done when:** A fresh system boots with all dotfiles properly applied.
- [ ] **DOT-04 — Fix link opening in Kitty/OpenCode to use current workspace** (ready, 3 pts)
  - **Why:** Links clicked in Kitty/OpenCode don't open on the current Hyprland workspace. A custom `xdg-mime` handler with `librewolf --new-window` didn't work.
  - **Start here:** `xdg-mime` handler config, Kitty/OpenCode link launch code, Hyprland workspace rules.
  - **Do:** Investigate the launch path and browser window placement; try an alternative handler that opens links in a new window on the current workspace.
  - **Done when:** Clicking a link in Kitty/OpenCode opens it in a new LibreWolf window on the current Hyprland workspace.
- [x] Add Quickshell themes: white, black or red (switch via `jetshell ipc call theme set <mode>` or `Super + T`; wallpaper-matched mode removed 2026-10-17).
- [x] **DOT-05 — Window screenshot keybind** — `Super + Alt + P` captures the focused window's client area; new `window` case in `screenshot.sh`; keybinds, HOWTO, and the README Hyprland-only line updated. Recheck: `hyprctl reload && hyprctl configerrors` clean, `Super + Shift + R` (record) still works.

## Split jetshell into its own repo

- [ ] **JSH-01 — Create the jetshell repo, squash-import the tree** (ready, 2 pts)
  - **Why:** `~/.config/jetshell/` and the parent dotfiles repo currently share history, so the shell cannot be installed or reviewed independently. A squash into a new repo at `~/code/jetshell` is the minimum to unblock everything below.
  - **Start here:** `~/.config/jetshell/`, `~/code/jetshell/`, `git-filter-repo` and a fresh remote.
  - **Do:** `git init ~/code/jetshell`, copy `jetshell/*` in (skip `__pycache__` per the parent `.gitignore`), single `chore: import from dotfiles (squash)` commit. Replace `~/.config/jetshell` with a symlink to `~/code/jetshell`. Add a one-line `~/.config/jetshell`-symlink note to HOWTO's JetShell section so a fresh clone of the dotfiles repo alone doesn't leave a dead symlink.
  - **Done when:** A fresh `git -C ~/code/jetshell log` shows one commit with the full tree, and `readlink ~/.config/jetshell` points at the new repo. `install.sh` / `update.sh` / `doctor.sh` still pass unchanged.
- [ ] **JSH-02 — Update parent repo docs to reflect the split** (blocked on JSH-01, 1 pt)
  - **Why:** `ARCHITECTURE.md`, `HOWTO.md` (JetShell section) and `ROADMAP.md` (this section) still describe jetshell as part of the dotfiles repo. The facts are right (the symlink sits where the directory used to be) but the install steps reference a path that no longer exists without the symlink.
  - **Start here:** `ARCHITECTURE.md`, `HOWTO.md`, `ROADMAP.md`.
  - **Do:** Edit the JetShell paragraph in `ARCHITECTURE.md` to mention the symlink and the new repo. Add a short "fresh install" subsection to HOWTO that documents the clone order (dotfiles first, then `~/code/jetshell`, then `ln -s`). Mark the previous text as historical.
  - **Done when:** Reading each doc, the install order is unambiguous and points at the right repos.
- [ ] **JSH-03 — Stop hardcoding the path in the launcher and the systemd unit** (blocked on JSH-01, 2 pts)
  - **Why:** `scripts/jetshell` pins `${XDG_CONFIG_HOME:-$HOME/.config}/jetshell` and `systemd/user/jetshell.service` pins `--path %h/.config/jetshell`. Both are fine while the symlink exists, and broken the moment someone clones just the shell repo. The current symlink approach papers over this; the abstraction needs to exist before a second consumer shows up.
  - **Start here:** `scripts/jetshell`, `systemd/user/jetshell.service`, Quickshell's `--path` docs.
  - **Do:** Add a `--path` / `JETSHELL_PATH` override to the launcher so a non-symlinked install works. Switch the unit's `ExecStart` to read the path from an env file (`EnvironmentFile=%h/.config/jetshell/path.conf`) or a drop-in; keep the existing default for compatibility.
  - **Done when:** Both the launcher and the unit accept an overridden path, and the existing dotfiles-repo install still behaves identically without an override.
- [ ] **JSH-04 — Decide whether the dotfiles repo ever tracks the new repo** (blocked on JSH-01, 1 pt)
  - **Why:** A symlink keeps the parent repo unaware of the shell's history, which is the point of the split, but a doc-only pointer would survive a fresh clone better than a dead symlink.
  - **Start here:** `scripts/install.sh`, `scripts/doctor.sh`, parent `ARCHITECTURE.md`.
  - **Do:** Pick one of: (a) leave it as a symlink and document it, (b) add the new repo as a git submodule with an `install.sh` step, (c) add it as a subtree. The recommendation is (a) for now; (b) only if a second consumer actually appears.
  - **Done when:** The decision is written down next to the JSH-01 entry and the right one is implemented.

## JetShell

- [ ] **Dock** — app dock with icons, workspace filtering, hover previews
- [ ] **Notification center** — dunst/notify-desktop integration
- [ ] **Lock screen** — time, password prompt, wake gesture
- [ ] **Media player widget** — MPRIS integration (Spotify, etc.)
- [ ] **Media player time scrubber** — validate reliability with Chromium and other MPRIS players, both playing and paused. `jetshell/AudioPlayerUI.qml` now previews locally during dragging, commits one absolute seek on release (Quickshell maps this to `SetPosition`), and cancels on track/player changes. Confirm playback lands at the selected timestamp without snapping back; the earlier claim that Chromium's position is read-only was not established.
- [ ] **Settings popup** — brightness, volume, theme cycling, network, bluetooth
- [ ] **System tray popover** — expandable menus for wifi, audio, battery
- [x] **Clipboard history** — `Super + Ctrl + V` (JetShell panel over cliphist; was Noctalia's clipboard panel)
- [ ] **Session / power menu** — `Super + O` (lock, logout, reboot, shutdown)
- [ ] **Caffeine toggle** — `Super + Shift + A` / `Super + Ctrl + A` idle inhibitor
- [ ] **Top-bar volume percentage position** — fix where the `NN%` label sits next to the volume bars in the top-left of the bar (`jetshell/TopBar.qml`, `volumePercent`, anchored to `volumeBars.right`)
- [ ] **Brightness / volume OSD** — on-screen feedback (the keys now drive `brightnessctl` / `wpctl` directly)
- [ ] **Tailscale and DNS widgets** — replaced the removed Noctalia plugins
- [ ] **Render GTK/btop/qt6ct palettes from Quickshell** — only kitty is generated today; the GTK palettes are frozen copies
- [ ] **MiniMax usage indicator** — the widget is data-driven, so MiniMax appears with no code change once the credential works; blocked because ai-usagebar's MiniMax vendor reads only `/v1/token_plan/remains`, which needs an active Token Plan, and the opencode key has none (`/v1/api/openplatform/charge/token_plan/usage` → `total_purchased: 0`). Unblocks by buying/assigning a Token Plan, or by putting the plan's team Subscription Key in `~/.config/ai-usagebar/config.toml` (`[minimax] api_key`). Entry is currently left armed there, so it starts reporting by itself.

## Ideas

- Desktop widgets
- Gaming mode toggle (disable shell animations, notifications)
- Kitty `--single-instance`: every `Super + Return` starts its own kitty process (~150 MB each). One shared process would save memory; launch is already ~100 ms, so only worth it if RAM gets tight. `sync-kitty-theme.sh` already loops over every `kitty-quickshell-*` socket, so it keeps working.
- Last personal bits in the repo: `rbw/config.json` and `rbw/pinentry-rbw` (vault URL, email, absolute pinentry path) plus the rbw HOWTO section. Options: untrack and move to `sync-private.sh`, or template them with a `*.example`.
