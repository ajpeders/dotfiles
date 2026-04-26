import QtQuick
import Quickshell.Services.Notifications

Item {
    id: notifications
    property int barHeight: 34
    width: 30

    NotificationServer {
        id: notifServer
    }

    Rectangle {
        id: bellBtn
        anchors.fill: parent
        radius: Theme.radius
        color: mouseArea.containsHover ? Theme.color0 : "transparent"
        opacity: mouseArea.containsHover ? 0.5 : 1.0

        Text {
            anchors.centerIn: parent
            text: "🔔"
            font.pixelSize: 14
        }

        // Unread count badge
        Rectangle {
            visible: notifServer.trackedNotifications.length > 0
            x: parent.width - 10
            y: 2
            width: 14
            height: 14
            radius: 7
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: notifServer.trackedNotifications.length
                color: Theme.background
                font.pixelSize: 9
                font.bold: true
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: app.showNotificationCenter()
    }
}
