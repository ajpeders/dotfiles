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

Singleton that reads `~/.cache/wallust/colors.json` and exposes colors as QML properties. Uses file watching for live reload when wallust regenerates colors.

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

**Left — Workspaces:**
- Buttons for each Hyprland workspace via Hyprland IPC
- Active workspace gets `accent` background, others get subtle hover states
- Shows workspace name/number (1–5, dev, server, work, game, config)
- Click to switch, scroll to cycle

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
- Fades in on hardware key press, 1.5s auto-dismiss timer resets on each press
- Mute shows crossed-out icon and dimmed bar
- Reads from PipeWire/PulseAudio via Quickshell audio service
- Replaces `volume.sh` — handles audio change + OSD in one place

### Brightness OSD

- Same design as Volume OSD, sun icon instead
- Reads from `brightnessctl`
- Same fade in/out behavior with 1.5s timer

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
  - Night Light — toggles `hyprsunset` or `gammastep`
  - Idle Inhibit — prevents screen lock/sleep
  - Game Mode — triggers `toggle-game-mouse.sh` + disable animations
- Volume slider and brightness slider below toggles
- Toggle buttons light up with accent color when active
- Escape or click outside to dismiss

### App Launcher (replaces Rofi)

- Triggered by `Super+Space` keybind
- Centered overlay with dimmed/blurred backdrop
- Search box at top, auto-focused
- Grid/list of matching apps (icons + name), ~600px wide
- Reads `.desktop` files for app entries
- Fuzzy matching as you type
- Most recently launched apps shown when search is empty
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
- Notifications persist until dismissed (JSON cache for persistence across restarts)

**Toast notifications:**
- Small popup in top-right corner, outside the panel
- Shows for 5s then slides away
- Stacks up to 3 visible, older ones collapse
- Clicking a toast opens the notification center

**Quickshell implements the freedesktop notification protocol directly — it becomes the notification daemon.**

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

- `Super+Space` — launches Quickshell launcher instead of Rofi
- Volume/brightness hardware keys — Quickshell handles OSD directly (or Hyprland dispatches to Quickshell via IPC)
- All bar-triggered panels (calendar, media, quick settings, notifications) are click-only, no keybinds

## install.sh Changes

- Add `quickshell` to symlinked configs
- Add `quickshell` and optional deps (`qtsvg`, `qtimageformats`, `qtmultimedia`, `qt5compat`) to `packages.txt`
- Remove `waybar`, `swaync`, `rofi` from symlinks (or keep as fallback)

## Dependencies

- `quickshell` (Arch: `pacman -S quickshell`)
- `qtsvg` — SVG support
- `qtimageformats` — WEBP and other formats
- `qtmultimedia` — audio/video playback
- `qt5compat` — visual effects (gaussian blur)
- `brightnessctl` — brightness OSD
- `nmcli` / `NetworkManager` — quick settings wifi
- `bluetoothctl` / `bluez` — quick settings bluetooth
