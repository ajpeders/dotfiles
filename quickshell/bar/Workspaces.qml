import QtQuick
import Quickshell.Hyprland

Item {
    id: workspaces
    property int barHeight: 34

    Row {
        height: barHeight
        spacing: 4

        Repeater {
            model: Hyprland.workspaces

            Rectangle {
                id: wsBtn
                width: 36
                height: barHeight - 6
                y: 3
                radius: Theme.radius
                color: model.active ? Theme.accent : Theme.color0
                opacity: model.active ? 1.0 : (mouseArea.containsMouse ? 0.7 : 0.3)

                property bool isNamed: model.name !== String(model.id)

                Text {
                    anchors.centerIn: parent
                    text: isNamed ? model.name : model.id
                    color: model.active ? Theme.background : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Hyprland.switchToWorkspace(model.id)
                }

                // Scroll to cycle workspaces
                WheelEventListener {
                    anchors.fill: parent
                    onWheel: (event) => {
                        const delta = event.angleDelta.y > 0 ? -1 : 1
                        const next = model.id + delta
                        if (next >= 1) Hyprland.switchToWorkspace(next)
                    }
                }
            }
        }

        // Active window title (truncated)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Hyprland.activeWindow.title
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
            maximumLineCount: 1
            width: 200
        }
    }
}
