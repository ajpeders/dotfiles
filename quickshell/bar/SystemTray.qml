import QtQuick
import Quickshell.Services.SystemTray

Item {
    id: tray
    property int barHeight: 34
    width: 30

    SystemTray {
        id: systemTray
    }

    Repeater {
        model: systemTray.items

        Rectangle {
            width: 24
            height: barHeight - 6
            y: 3
            radius: Theme.radius
            color: Theme.color0
            opacity: 0.6

            Image {
                anchors.centerIn: parent
                source: model.icon || ""
                width: 16
                height: 16
            }

            MouseArea {
                anchors.fill: parent
                onClicked: systemTray.activate(model.id)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "▲"
        color: Theme.textMuted
        font.pixelSize: 10
    }
}
