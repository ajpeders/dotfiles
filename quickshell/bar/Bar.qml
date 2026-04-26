import Quickshell
import Quickshell.Hyprland._Ipc
import QtQuick
import QtQuick.Layouts

Row {
    id: bar
    anchors.fill: parent
    spacing: 10
    padding: 8

    // Left — workspaces
    WorkspacesModule { }

    // Center — clock
    ClockModule { }

    // Right — placeholder for now
    Item { Layout.fillWidth: true }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "test"
        color: "#cdd6f4"
        font.family: "JetBrains Mono"
    }
}
