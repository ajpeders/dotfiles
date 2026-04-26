import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._Ipc
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import QtQuick

Row {
    id: bar

    // Set by shell via Loader.onLoaded: item.parentShell = barWindow
    property var parentShell: null

    anchors.fill: parent
    spacing: 0

    Workspaces { }

    Item { width: 10; height: parent.height }

    Clock { }

    Item { width: 10; height: parent.height }

    Item { width: 10; height: parent.height }
    Item { Layout.fillWidth: true; height: parent.height }

    MediaControls {
        onOpenMedia: parentShell ? parentShell.shell.showMediaPopup() : null
    }

    VolumeSlider { }

    Weather { }

    SystemTrayItem { }

    QuickSettingsButton {
        onOpenQuickSettings: parentShell ? parentShell.shell.showQuickSettings() : null
    }

    NotificationBell {
        onOpenNotifications: parentShell ? parentShell.shell.showNotificationCenter() : null
    }
}
