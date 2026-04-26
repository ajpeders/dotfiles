# Quickshell Desktop Shell — Design Spec

## Overview

Full Quickshell-based desktop shell for Hyprland, replacing Waybar, swaync, Rofi, nm-applet, and blueman-applet. QML-based, modular architecture with wallust (Kanagawa-Wave) theming and live color reload.

## Directory Structure

```
~/.config/quickshell/
├── shell.qml                  # Entry point — loads all components
├── .qmlls.ini                 # LSP config
├── Theme.qml                  # Singleton: wallust colors, fonts, spacing
├── bar/
│   ├── Bar.qml                # Bar panel (per-monitor)
│   ├── Workspaces.qml         # Hyprland workspace buttons
│   ├── Clock.qml              # Clock + calendar dropdown
│   ├── MediaControls.qml      # Mpris: current track, play/pause
│   ├── VolumeSlider.qml       # PulseAudio volume
│   ├── Weather.qml            # wttr.in weather display
│   ├── SystemTray.qml         # System tray
│   └── Notifications.qml      # Notification indicator + bell icon
├── osd/
│   ├── VolumeOsd.qml          # Volume change popup
│   └── BrightnessOsd.qml      # Brightness change popup
├── media/
│   └── MediaPopup.qml         # Full media popup: art, controls, progress
├── monitor/
│   └── SystemMonitor.qml      # CPU/RAM/GPU floating widget
├── quicksettings/
│   └── QuickSettings.qml      # Wifi, BT, DND, toggles panel
├── launcher/
│   └── Launcher.qml           # App launcher (replaces Rofi)
└── notifications/
    └── NotificationCenter.qml # Full notification center (replaces swaync)
```

## Theming — Theme.qml

Singleton that reads wallust-generated colors and exposes them as QML properties. Uses file watching for live reload when wallust regenerates.

### Color Source

A custom wallust template (`quickshell.json`) outputs the 16-color palette + foreground/background as JSON to `~/.cache/wallust/quickshell-colors.json`. The template must be added to `wallust.toml` alongside the existing templates. Theme.qml parses this JSON on startup and watches the file for changes.

### Color Properties

- `background`, `foreground` — base colors
- `color0`–`color15` — full 16-color palette
- `accent` — derived from palette for highlights/active states
- `panelBg` — background with alpha for blur/transparency
- `borderColor` — subtle separator color

### Design Tokens

- `fontFamily` — matches current Waybar font
- `fontSize: 13`
- `radius: 8` — rounded corners, flat/modern
- `padding: 8`
- `animDuration: 150` — consistent animation speed

### Style Direction

Flat, modern, minimal. Kanagawa-Wave palette. Semi-transparent blur backgrounds, accent highlights. No bevels, no 3D effects.

## Components

### Bar

- `PanelWindow` anchored top of each monitor, ~34px height
- Blur-backed with `panelBg`
- Layout: Left | Center | Right

**Left — Workspaces + Active Window:**
- Buttons for each Hyprland workspace via Hyprland IPC
- Active workspace gets `accent` background, others get subtle hover states
- Shows workspace name/number (1–5, dev, server, work, game, config)
- Each monitor's bar shows all workspaces, but highlights which are on that monitor
- `magic` (scratchpad) workspace is not shown in the bar
- Click to switch, scroll to cycle
- Active window title displayed after workspace buttons (truncated)

**Center — Clock:**
- Time in `HH:MM`, date on hover tooltip
- Click opens Calendar dropdown (grid calendar, month navigation)

**Right — grouped:**
- Media: current track + artist (truncated), play/pause icon. Click opens MediaPopup
- Volume: icon reflects mute/level. Click opens VolumeSlider dropdown. Scroll to adjust
- Weather: icon + temp from wttr.in, tooltip with details. 30min poll
- System Tray: native Wayland tray via Quickshell's SystemTray type
- Quick Settings: gear icon, click opens QuickSettings panel
- Notification bell: icon with unread count badge, click opens NotificationCenter

**Behavior:**
- Hover on any module shows tooltip
- Dropdowns/popups appear below bar, aligned to triggering module
- Bar auto-hides on exclusive fullscreen

### Volume OSD

- Centered horizontal pill, ~300px wide
- Speaker icon left, progress bar right
- Semi-transparent blur background, accent color fill
- Fades in on volume change, 1.5s auto-dismiss timer resets on each change
- Mute shows crossed-out icon and dimmed bar

**Trigger mechanism:** Hyprland keybinds call Quickshell via IPC socket (`quickshell volume up/down/mute`). Quickshell performs the volume change using PipeWire/PulseAudio APIs and shows the OSD. This preserves the smart sink detection logic from the current `volume.sh` (running sink > sink-for-input > default sink).

### Brightness OSD

- Same design as Volume OSD, sun icon instead
- Same fade in/out behavior with 1.5s timer

**Trigger mechanism:** Hyprland keybinds call Quickshell via IPC socket (`quickshell brightness up/down`). Quickshell calls `brightnessctl` to change brightness, reads back the new value, and shows the OSD. Alternatively, Quickshell watches `/sys/class/backlight/*/brightness` via inotify for changes from any source.

### Media Popup

- ~320px wide dropdown below bar, triggered by clicking media module
- Album art thumbnail (left), track/artist/album text (right)
- Progress bar with elapsed/total time (draggable to seek)
- Transport controls: previous, play/pause, next
- Source label if multiple players, selector to switch
- MPRIS integration via Quickshell
- Escape or click outside to dismiss

### System Monitor

- Floating widget, not part of bar
- Toggled from Quick Settings panel
- ~200px wide, stacked rows: CPU, RAM, GPU
- Each row: label, percentage, thin horizontal bar with accent fill
- CPU/RAM: poll `/proc/stat` and `/proc/meminfo` every 2s
- GPU: NVIDIA via `nvidia-smi`, AMD via `/sys/class/drm`
- Draggable to position anywhere on screen
- Remembers position between toggles (not across restarts)
- Semi-transparent blur background

### Quick Settings Panel

- ~300px wide dropdown from bar, triggered by clicking gear icon
- Grid of toggle buttons (2 columns):
  - Wi-Fi — on/off, shows SSID (via `nmcli`)
  - Bluetooth — on/off, shows device name (via `bluetoothctl`)
  - Do Not Disturb — suppresses notifications (internal flag)
  - Night Light — toggles `hyprsunset`
  - Idle Inhibit — prevents screen lock/sleep
  - Game Mode — toggles Hyprland animations off + adjusts mouse settings via `hyprctl`
- Volume slider and brightness slider below toggles
- Toggle buttons light up with accent color when active
- Escape or click outside to dismiss

### App Launcher (replaces Rofi)

- Triggered by `Super+Space` keybind
- Centered overlay with dimmed/blurred backdrop
- Search box at top, auto-focused
- Grid/list of matching apps (icons + name), ~600px wide
- Reads `.desktop` files from standard XDG paths (`/usr/share/applications`, `~/.local/share/applications`)
- Substring matching as you type (simple, reliable — upgrade to fuzzy later if needed)
- Most recently launched apps shown when search is empty (tracked in `~/.cache/quickshell/launcher-history.json`)
- Enter launches top result, arrow keys to navigate
- Escape or click outside to dismiss

### Notification Center (replaces swaync)

**Panel:**
- Slide-in from right edge, full screen height, ~380px wide
- Triggered by clicking notification bell in bar
- Header: "Notifications" title + "Clear All" button
- DND toggle at top
- Scrollable list grouped by app
- Each notification: app icon + name + timestamp, title (bold) + body, action buttons if provided, dismiss (X) button
- Escape or click outside to dismiss
- Notifications persist until dismissed (JSON cache at `~/.cache/quickshell/notifications.json`, max 100 entries, oldest auto-pruned)

**Toast notifications:**
- Small popup in top-right corner, outside the panel
- Shows for 5s then slides away
- Stacks up to 3 visible, older ones collapse
- Clicking a toast opens the notification center

**Quickshell implements the freedesktop notification protocol directly — it becomes the notification daemon.**

## Graceful Degradation

- **Weather (wttr.in unreachable):** Show "—" instead of temp, retry on next poll cycle
- **MPRIS (no players):** Media module hides from bar, MediaPopup shows "Nothing playing"
- **PipeWire not running:** Volume module shows muted icon, OSD shows error state
- **NetworkManager not running:** Wi-Fi toggle grayed out with "Unavailable" label
- **Bluetooth not running:** Bluetooth toggle grayed out
- **GPU not detected:** System Monitor omits GPU row

## Autostart Changes

Replace in `hypr/config/autostart.conf`:

**Remove:**
- `waybar`
- `swaync`
- `nm-applet --indicator`
- `blueman-applet`

**Add:**
- `quickshell`

## Keybind Changes

- `Super+Space` — Quickshell launcher instead of Rofi
- `Super+V` — Quickshell clipboard history popup instead of `cliphist | rofi` (reads from cliphist, displays in Quickshell)
- Volume keys (`XF86Audio*`) — dispatch to Quickshell IPC for volume change + OSD
- Brightness keys (`XF86MonBrightness*`) — dispatch to Quickshell IPC for brightness change + OSD
- Media transport keys (`XF86AudioNext/Prev/Play`) — keep as Hyprland keybinds calling `playerctl` (works fine as-is)
- All bar-triggered panels (calendar, media, quick settings, notifications) are click-only, no keybinds

## install.sh Changes

- Add `quickshell` to symlinked configs
- Add `quickshell` and optional deps (`qt6-svg`, `qt6-imageformats`, `qt6-multimedia`, `qt6-5compat`) to `packages.txt`
- Remove `waybar`, `swaync`, `rofi` from symlinks (or keep as fallback)

## Dependencies

- `quickshell` (Arch: `pacman -S quickshell`)
- `qt6-svg` — SVG support
- `qt6-imageformats` — WEBP and other formats
- `qt6-multimedia` — audio/video playback
- `qt6-5compat` — visual effects (gaussian blur via MultiEffect)
- `brightnessctl` — brightness OSD
- `nmcli` / `NetworkManager` — quick settings wifi
- `bluetoothctl` / `bluez` — quick settings bluetooth
