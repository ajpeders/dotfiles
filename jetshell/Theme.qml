pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme
    property string mode: "white"
    readonly property string fontFamily: barFont.name
    readonly property string regularFontFamily: regularFont.name
    // Each theme keeps its own wallpaper; a mode with none picked uses the fallback
    // (the pre-per-theme saved wallpaper, else the default image).
    property var wallpapers: ({})
    property string fallbackWallpaper: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers/upscaled_maoguin.png"
    readonly property string wallpaper: wallpapers[mode] || fallbackWallpaper
    // "red" is ink, paper and vermilion, sampled from the default wallpaper.
    readonly property color targetBase: mode === "black" ? "#080808" : mode === "red" ? "#0e0c0a" : "#c0c0c0"
    readonly property color targetForeground: mode === "black" ? "#ffffff" : mode === "red" ? "#ecddb5" : "#111111"
    // The colours the UI binds to fade to their targets on a theme change.
    readonly property int fadeDuration: 800
    property color base: targetBase
    property color background: mode === "white" ? targetBase
                               : Qt.rgba(targetBase.r, targetBase.g, targetBase.b, 0.93)
    property color foreground: targetForeground
    property color panelBorder: mode === "white" ? "#6e6e6e" : mode === "red" ? "#d94420" : targetForeground
    Behavior on base { ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad } }
    Behavior on background { ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad } }
    Behavior on foreground { ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad } }
    Behavior on panelBorder { ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad } }

    onModeChanged: kittySync.restart()

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
                                   theme.mode, theme.targetBase.toString(), theme.targetForeground.toString()]
            kittyUpdate.running = true
        }
    }

    Process { id: kittyUpdate }

    function setMode(value) {
        if (!["white", "black", "red"].includes(value)) return
        mode = value
        savedMode.setText(mode + "\n")
    }

    function cycle() {
        setMode(mode === "white" ? "black" : mode === "black" ? "red" : "white")
    }

    function setWallpaper(url) {
        const next = Object.assign({}, wallpapers)
        next[mode] = url.toString()
        wallpapers = next
        savedWallpapers.setText(JSON.stringify(next) + "\n")
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

    FileView {
        id: savedMode
        path: Quickshell.statePath("theme")
        printErrors: false // No saved choice on first launch.
        onLoaded: {
            const value = text().trim()
            // "wallpaper" mode was removed; a saved choice of it falls back to black.
            if (["white", "black", "red"].includes(value)) theme.mode = value
            else if (value === "wallpaper") theme.mode = "black"
        }
    }

    FileView {
        id: savedWallpaper
        path: Quickshell.statePath("wallpaper")
        printErrors: false
        onLoaded: {
            const value = text().trim()
            if (value.startsWith("file://")) theme.fallbackWallpaper = value
        }
    }

    FileView {
        id: savedWallpapers
        path: Quickshell.statePath("wallpapers")
        printErrors: false // No per-theme choice yet.
        onLoaded: {
            let saved = {}
            try { saved = JSON.parse(text()) } catch (e) { return }
            const valid = {}
            for (const key of ["white", "black", "red"])
                if (typeof saved[key] === "string" && saved[key].startsWith("file://")) valid[key] = saved[key]
            theme.wallpapers = valid
        }
    }
}
