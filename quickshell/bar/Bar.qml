import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._Ipc
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import QtQuick

Row {
    id: bar
    anchors.fill: parent
    spacing: 0

    Workspaces { }

    Item { width: 10; height: parent.height }

    Clock { }

    Item { width: 10; height: parent.height }

    Item { width: 10; height: parent.height }
    Item { Layout.fillWidth: true; height: parent.height }

    MediaControls {
        // bar (Row) → contentItem → PanelWindow → shell
        onOpenMedia: bar.parent.parent.shell.showMediaPopup()
    }

    VolumeSlider { }

    Weather { }

    SystemTrayItem { }

    QuickSettingsButton {
        onOpenQuickSettings: bar.parent.parent.shell.showQuickSettings()
    }

    NotificationBell {
        onOpenNotifications: bar.parent.parent.shell.showNotificationCenter()
    }
}
