pragma Singleton
import QtQuick
import QtCore

QtObject {
    id: theme

    // Color properties — populated from wallust JSON
    property color background: "#1a1a2e"
    property color foreground: "#cdd6f4"
    property color color0: "#45475a"
    property color color1: "#f38ba8"
    property color color2: "#a6e3a1"
    property color color3: "#f9e2af"
    property color color4: "#89b4fa"
    property color color5: "#cba6f7"
    property color color6: "#94e2d5"
    property color color7: "#bac2de"
    property color color8: "#585b70"
    property color color9: "#f38ba8"
    property color color10: "#a6e3a1"
    property color color11: "#f9e2af"
    property color color12: "#89b4fa"
    property color color13: "#cba6f7"
    property color color14: "#94e2d5"
    property color color15: "#a6adc8"

    // Derived colors
    property color accent: color5
    property color panelBg: background
    property color panelBgAlpha: background
    property color borderColor: color0
    property color textSecondary: color7
    property color textMuted: color8

    // Design tokens
    property string fontFamily: "JetBrains Mono"
    property int fontSize: 13
    property int radius: 8
    property int padding: 8
    property int animDuration: 150

    // File path to color cache
    readonly property string colorFile: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0] + "/.cache/wallust/quickshell-colors.json"

    // Load colors from JSON file
    function loadColors() {
        const file = new File(colorFile)
        if (!file.exists) return

        try {
            const data = JSON.parse(file.read())
            background = data.background || background
            foreground = data.foreground || foreground
            color0 = data.color0 || color0
            color1 = data.color1 || color1
            color2 = data.color2 || color2
            color3 = data.color3 || color3
            color4 = data.color4 || color4
            color5 = data.color5 || color5
            color6 = data.color6 || color6
            color7 = data.color7 || color7
            color8 = data.color8 || color8
            color9 = data.color9 || color9
            color10 = data.color10 || color10
            color11 = data.color11 || color11
            color12 = data.color12 || color12
            color13 = data.color13 || color13
            color14 = data.color14 || color14
            color15 = data.color15 || color15
            accent = data.accent || color5
        } catch (e) {
            console.warn("Theme: failed to parse colors:", e)
        }
    }

    // Watch for wallust regeneration
    FileWatcher {
        id: watcher
        path: theme.colorFile
        onChanged: theme.loadColors()
    }

    // Load on startup
    Component.onCompleted: loadColors()
}
