import Quickshell
import Quickshell._Window
import Quickshell.Services.Notifications
import QtQuick

FloatingWindow {
    id: notifCenter
    width: 380
    height: Quickshell.screens[0].height
    // Right edge of primary screen
    x: Quickshell.screens[0].width - width
    y: 0
    visible: false
    focusable: true
    color: "transparent"

    NotificationServer {
        id: notifServer
    }

    OpacityAnimator {
        id: slideIn
        target: notifCenter
        from: 0
        to: 1
        duration: Theme.animDuration
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg

        Column {
            anchors.fill: parent
            padding: Theme.padding
            spacing: Theme.padding

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

                Item { Layout.fillWidth: true; height: 1 }

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

            ListView {
                id: notifList
                width: parent.width
                height: parent.height - 40
                clip: true

                model: notifServer.trackedNotifications

                delegate: Rectangle {
                    width: notifList.width
                    height: 70
                    radius: Theme.radius
                    color: Theme.color0

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

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
                                Item { Layout.fillWidth: true; height: 1 }
                                Text { text: model.timestamp || ""; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 3 }
                            }

                            Text {
                                text: model.title || ""
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: true
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                            }

                            Text {
                                text: model.body || ""
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideMiddle
                                maximumLineCount: 2
                            }
                        }

                        Text {
                            text: "✕"
                            color: Theme.textMuted
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
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

    function toggle() {
        visible = !visible
        if (visible) slideIn.start()
    }
}
