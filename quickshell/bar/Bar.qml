import QtQuick
import Quickshell
import Quickshell.Panels
import Quickshell.Hyprland

PanelWindow {
    id: bar
    anchor: PanelWindow.Top
    screen: screen
    height: 34
    margins: 0
    exclusiveZone: 1
    layer: PanelWindow.Above

    background: Rectangle {
        color: Theme.panelBg
        opacity: 0.85
    }

    // Blur effect
    // MultiEffect from Qt5Compat for blur (loaded via qt6-5compat)
    // Fallback to flat color if blur unavailable

    Row {
        anchors.fill: parent
        spacing: 0

        // Left — workspaces + active window
        Workspaces {
            barHeight: bar.height
        }

        // Spacer
        Item { width: 10; barHeight: bar.height }

        // Center — clock
        Clock {
            barHeight: bar.height
        }

        // Spacer takes remaining space
        Item { Layout.fillWidth: true }

        // Right — media, volume, weather, tray, quick settings, notifications
        MediaControls {
            barHeight: bar.height
        }

        VolumeSlider {
            barHeight: bar.height
        }

        Weather {
            barHeight: bar.height
        }

        SystemTray {
            barHeight: bar.height
        }

        QuickSettingsButton {
            barHeight: bar.height
        }

        Notifications {
            barHeight: bar.height
        }
    }
}
