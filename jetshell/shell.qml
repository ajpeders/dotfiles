//@ pragma UseQApplication

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

ShellRoot {
    AppLauncher {
        id: launcher
    }

    NotificationCenter {
        id: notificationCenter
    }

    ClipboardPanel {
        id: clipboard
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (launcher.visible) launcher.close()
            else launcher.open()
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            if (notificationCenter.visible) notificationCenter.close()
            else notificationCenter.open()
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            if (clipboard.visible) clipboard.close()
            else clipboard.open()
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background

            Image {
                anchors.fill: parent
                source: Theme.wallpaper
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                layer.enabled: Theme.mode === "white"
                layer.effect: MultiEffect { saturation: -1.0 }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        TopBar {
            property var modelData
            screen: modelData
        }
    }

    VolumeOsd {}
}
