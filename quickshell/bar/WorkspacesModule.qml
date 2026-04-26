import Quickshell.Hyprland._Ipc
import QtQuick

Row {
    spacing: 4

    Repeater {
        model: Hyprland.workspaces

        Rectangle {
            width: 32
            height: 26
            radius: 6
            color: modelData.active ? "#cba6f7" : "#45475a"

            Text {
                anchors.centerIn: parent
                text: modelData.name || String(modelData.id)
                color: modelData.active ? "#1a1a2e" : "#cdd6f4"
                font.family: "JetBrains Mono"
                font.pixelSize: 12
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
