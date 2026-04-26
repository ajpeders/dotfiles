import Quickshell
import Quickshell._Window
import QtQuick

FloatingWindow {
    id: clipboardPopup
    width: 400
    height: 400
    x: (Quickshell.screens[0].width - width) / 2
    y: (Quickshell.screens[0].height - height) / 2
    visible: false
    focusable: true
    color: "transparent"

    OpacityAnimator {
        id: fadeIn
        target: clipboardPopup
        from: 0
        to: 1
        duration: Theme.animDuration
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
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
                    text: "Clipboard History"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Item { Layout.fillWidth: true; height: 1 }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: Theme.textMuted
                    font.pixelSize: 14
                    MouseArea { anchors.fill: parent; onClicked: clipboardPopup.visible = false }
                }
            }

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
                        text: model.text || ""
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
                            clipboardPopup.visible = false
                        }
                    }
                }
            }
        }
    }

    property var clipboardItems: []

    function loadHistory() {
        const xhr = new XMLHttpRequest()
        xhr.open("GET", "file:///tmp/cliphist.json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                // Fallback: try cliphist directly
                loadHistoryFallback()
                return
            }
            try {
                clipboardItems = JSON.parse(xhr.responseText)
            } catch (e) {
                loadHistoryFallback()
            }
        }
        xhr.send()
    }

    function loadHistoryFallback() {
        // cliphist list -> parse output
        clipboardItems = []
        const proc = Process
        // Would need async process — simplified for now
    }

    function toggle() {
        visible = !visible
        if (visible) {
            loadHistory()
            fadeIn.start()
        }
    }
}
