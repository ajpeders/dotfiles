import QtQuick
import Quickshell.Panels
import Quickshell.Services.Notifications

PopupWindow {
    id: notifCenter
    anchor: PopupWindow.RightEdge
    width: 380
    height: parent ? parent.height : 800
    margin: 0
    closePolicy: PopupWindow.ClickOutside | PopupWindow.Escape
    focusable: true

    NotificationServer {
        id: notifServer
        persistenceSupported: true
        keepOnReload: true
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg

        Column {
            anchors.fill: parent
            padding: Theme.padding
            spacing: Theme.padding

            // Header
            Row {
                width: parent.width
                height: 30

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Item { Layout.fillWidth: true }

                // DND toggle
                Rectangle {
                    width: 70
                    height: 24
                    radius: 12
                    color: notifServer.dnd ? Theme.accent : Theme.color0

                    Text {
                        anchors.centerIn: parent
                        text: notifServer.dnd ? "DND" : "Normal"
                        color: notifServer.dnd ? Theme.background : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: notifServer.dnd = !notifServer.dnd
                    }
                }

                // Clear all
                Rectangle {
                    width: 70
                    height: 24
                    radius: Theme.radius
                    color: Theme.color0

                    Text {
                        anchors.centerIn: parent
                        text: "Clear All"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: notifServer.clearAll()
                    }
                }
            }

            // Notification list
            ListView {
                id: notifList
                width: parent.width
                height: parent.height - 40
                clip: true

                model: notifServer.trackedNotifications

                delegate: Rectangle {
                    width: notifList.width
                    height: notifRowHeight
                    radius: Theme.radius
                    color: Theme.color0

                    property int notifRowHeight: 70

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        // App icon
                        Image {
                            width: 24
                            height: 24
                            source: model.icon || ""
                            fillMode: Image.PreserveAspectFit
                        }

                        Column {
                            width: parent.width - 60
                            spacing: 2

                            Row {
                                width: parent.width
                                Text { text: model.appName || ""; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                                Item { Layout.fillWidth: true }
                                Text { text: model.timestamp || ""; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 3 }
                            }

                            Text { text: model.title || ""; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; font.bold: true }
                            Text {
                                text: model.body || ""
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideMiddle
                                maximumLineCount: 2
                            }
                        }

                        // Dismiss button
                        Text {
                            text: "✕"
                            color: Theme.textMuted
                            font.pixelSize: 12
                            MouseArea {
                                anchors.fill: parent
                                onClicked: notifServer.dismiss(model.id)
                            }
                        }
                    }
                }
            }
        }
    }

    function open() {
        notifCenter.visible = true
    }
}
