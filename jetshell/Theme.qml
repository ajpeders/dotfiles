pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme
    property string mode: "white"
    readonly property string fontFamily: barFont.name
    readonly property string regularFontFamily: regularFont.name
    property string wallpaper: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers/upscaled_maoguin.png"
    readonly property color base: mode === "black" ? "#080808"
                                  : mode === "wallpaper" && palette.colors.length ? palette.colors[0] : "#e6e2de"
    readonly property color background: mode === "white" ? base : Qt.rgba(base.r, base.g, base.b, 0.93)
    readonly property color foreground: mode === "black" ? "#ffffff"
        : mode === "white" ? "#111111" : luminance(base) > 0.179 ? "#111111" : "#ffffff"
    readonly property color panelBorder: mode === "white" ? "#918981" : foreground

    onModeChanged: kittySync.restart()
    onBaseChanged: kittySync.restart()
    onForegroundChanged: kittySync.restart()

    Timer {
        id: kittySync
        interval: 100
        running: true
        onTriggered: {
            if (kittyUpdate.running) {
                restart()
                return
            }
            kittyUpdate.command = ["bash", Quickshell.shellPath("sync-kitty-theme.sh"),
                                   theme.mode, theme.base.toString(), theme.foreground.toString()]
            kittyUpdate.running = true
        }
    }

    Process { id: kittyUpdate }

    function luminance(color) {
        function linear(channel) {
            return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }

    function setMode(value) {
        if (!["white", "black", "wallpaper"].includes(value)) return
        mode = value
        savedMode.setText(mode + "\n")
    }

    function cycle() {
        setMode(mode === "white" ? "black" : mode === "black" ? "wallpaper" : "white")
    }

    function setWallpaper(url) {
        wallpaper = url.toString()
        savedWallpaper.setText(wallpaper + "\n")
    }

    FontLoader {
        id: barFont
        source: Qt.resolvedUrl("fonts/Tamzen8x16b.ttf")
    }

    FontLoader {
        id: regularFont
        source: Qt.resolvedUrl("fonts/Tamzen8x16r.ttf")
    }

    IpcHandler {
        target: "theme"
        function set(value: string): void { theme.setMode(value) }
        function get(): string { return theme.mode }
        function cycle(): void { theme.cycle() }
        function setWallpaper(value: string): void {
            theme.setWallpaper(value.startsWith("file://") ? value : "file://" + value)
        }
        function getWallpaper(): string { return theme.wallpaper }
    }

    ColorQuantizer {
        id: palette
        source: theme.wallpaper
        depth: 3
        rescaleSize: 64
    }

    FileView {
        id: savedMode
        path: Quickshell.statePath("theme")
        printErrors: false // No saved choice on first launch.
        onLoaded: {
            const value = text().trim()
            if (["white", "black", "wallpaper"].includes(value)) theme.mode = value
        }
    }

    FileView {
        id: savedWallpaper
        path: Quickshell.statePath("wallpaper")
        printErrors: false
        onLoaded: {
            const value = text().trim()
            if (value.startsWith("file://")) theme.wallpaper = value
        }
    }
}
