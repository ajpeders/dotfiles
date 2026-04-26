import QtQuick
import Quickshell.Hyprland._Ipc

Item {
    id: workspaces
    property int barHeight: 34

    // Named workspaces: 1-5 + dev(6) + server(7) + work(8) + game(9) + config(10)
    property var workspaceNames: {
        1: "1", 2: "2", 3: "3", 4: "4", 5: "5",
        6: "dev", 7: "server", 8: "work", 9: "game", 10: "config"
    }

    Row {
        height: barHeight
        spacing: 4

        Repeater {
            model: Hyprland.workspaces

            Rectangle {
                id: wsBtn
                width: wsLabel.width + 12
                height: barHeight - 6
                y: 3
                radius: Theme.radius
                color: modelData.active ? Theme.accent : Theme.color0
                opacity: modelData.active ? 1.0 : (mouseArea.containsMouse ? 0.7 : 0.3)

                property string wsName: modelData.name || String(modelData.id)
                property string displayName: workspaceNames[modelData.id] || wsName

                Text {
                    id: wsLabel
                    anchors.centerIn: parent
                    text: displayName
                    color: modelData.active ? Theme.background : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Hyprland.dispatch(`workspace ${modelData.id}`)
                }

                WheelEventListener {
                    anchors.fill: parent
                    onWheel: (event) => {
                        const delta = event.angleDelta.y > 0 ? -1 : 1
                        const next = modelData.id + delta
                        if (next >= 1) Hyprland.dispatch(`workspace ${next}`)
                    }
                }
            }
        }

        // Active window title
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
            maximumLineCount: 1
            width: 200
        }
    }
}
