import QtQuick
import Quickshell.Panels

PopupWindow {
    id: clipboardPopup
    width: 400
    height: 400
    anchor: PopupWindow.Center
    margin: 10
    closePolicy: PopupWindow.ClickOutside | PopupWindow.Escape
    focusable: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panelBg

        Column {
            anchors.fill: parent
            padding: Theme.padding
            spacing: Theme.padding

            // Header
            Row {
                width: parent.width
                Text {
                    text: "Clipboard History"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "✕"
                    color: Theme.textMuted
                    font.pixelSize: 14
                    MouseArea { anchors.fill: parent; onClicked: clipboardPopup.close() }
                }
            }

            // Clipboard list
            ListView {
                id: clipboardList
                width: parent.width
                height: parent.height - 40
                clip: true

                model: clipboardItems

                delegate: Rectangle {
                    width: clipboardList.width
                    height: 50
                    radius: Theme.radius
                    color: Theme.color0

                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
                        text: model.text
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideMiddle
                        maximumLineCount: 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Process.start("wl-copy", [model.text])
                            clipboardPopup.close()
                        }
                    }
                }
            }
        }
    }

    property var clipboardItems: []

    function loadHistory() {
        // Read from cliphist: cliphist list | head -20
        // Parse output and populate clipboardItems
        clipboardItems = []
    }

    Component.onCompleted: loadHistory()
}
