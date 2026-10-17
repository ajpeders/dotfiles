import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

PanelWindow {
    id: center
    visible: Notifications.centerOpen
    implicitWidth: 400
    implicitHeight: 480
    color: "transparent"
    anchors {
        top: true
        right: true
    }
    margins.top: 30
    margins.right: 12
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    onVisibleChanged: grab.active = visible

    property real itemHeight: 72

    function open() {
        const monitor = Hyprland.focusedMonitor
        const target = Quickshell.screens.find(s => monitor && s.name === monitor.name)
        if (target) screen = target
        Notifications.centerOpen = true
    }

    function close() {
        Notifications.centerOpen = false
    }

    HyprlandFocusGrab {
        id: grab
        windows: [center]
        onCleared: Notifications.centerOpen = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Theme.background
        border.width: 1
        border.color: Theme.panelBorder
        opacity: 0.92

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header
            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                Text {
                    text: "Notifications"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: false
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: String(Notifications.trackedNotifications.values.length)
                    color: Theme.foreground
                    opacity: 0.6
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 14
                }

                Text {
                    text: "Clear all"
                    color: Theme.foreground
                    opacity: 0.5
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 13

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            for (const notification of Notifications.trackedNotifications.values.slice())
                                notification.dismiss()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.foreground
                opacity: 0.15
            }

            // Notification list
            Repeater {
                model: Notifications.trackedNotifications

                Rectangle {
                    required property var modelData
                    width: parent.width
                    height: center.itemHeight
                    radius: 0
                    color: modelData.urgency === NotificationUrgency.Critical
                            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                            : "transparent"
                    border.width: modelData.urgency === NotificationUrgency.Critical ? 1 : 0
                    border.color: Theme.foreground

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Icon
                        Image {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignTop
                            source: modelData.image || modelData.appIcon || ""
                            fillMode: Image.PreserveAspectFit
                            visible: source !== ""
                            clip: true
                        }

                        // Content
                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.summary
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: false
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: modelData.body
                                color: Theme.foreground
                                opacity: 0.7
                                font.family: Theme.regularFontFamily
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                width: parent.width
                                visible: text !== ""
                            }

                            // Actions
                            Flow {
                                visible: modelData.actions.length > 0
                                width: parent.width
                                spacing: 6
                                anchors.topMargin: 4

                                Repeater {
                                    model: modelData.actions
                                    Rectangle {
                                        required property var modelData
                                        width: actionLabel.implicitWidth + 16
                                        height: 26
                                        radius: 0
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Theme.foreground
                                        opacity: 0.6

                                        Text {
                                            id: actionLabel
                                            anchors.centerIn: parent
                                            text: modelData.text
                                            color: Theme.foreground
                                            font.family: Theme.regularFontFamily
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: modelData.invoke()
                                        }
                                    }
                                }
                            }
                        }

                        // Dismiss button
                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignTop

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: modelData.dismiss()
                                cursorShape: Qt.PointingHandCursor

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: Theme.foreground
                                    opacity: parent.containsMouse ? 1 : 0.4
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                }
                            }
                        }
                    }
                }
            }

            // Empty state
            Text {
                visible: Notifications.trackedNotifications.values.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "No notifications"
                color: Theme.foreground
                opacity: 0.4
                font.family: Theme.regularFontFamily
                font.pixelSize: 14
            }
        }
    }
}
