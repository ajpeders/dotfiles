import Quickshell
import Quickshell._Window
import QtQuick

FloatingWindow {
    id: volumeDropdown
    width: 240
    height: 60
    visible: false
    focusable: true
    color: "transparent"

    property var targetItem: null

    function reposition(item) {
        if (!item) return
        const rect = item.window.itemRect(item)
        x = rect.x + rect.width / 2 - width / 2
        y = rect.y + rect.height
    }

    property int volumeLevel: 100
    property bool isMuted: false

    Process {
        id: volReader
        onFinished: (code) => {
            if (code !== 0) return
            const out = volReader.read()
            const match = out.match(/Volume:\s*([\d.]+)/)
            if (match) volumeLevel = Math.round(parseFloat(match[1]) * 100)
            isMuted = out.includes("Muted")
        }
    }

    function refresh() {
        volReader.start("wpctl", ["get-volume", "@DEFAULT_AUDIO_SINK@"])
    }

    Component.onCompleted: refresh()

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panelBg

        Row {
            anchors.fill: parent
            padding: Theme.padding
            spacing: 12

            Rectangle {
                width: 36
                height: 36
                radius: Theme.radius
                color: isMuted ? Theme.accent : Theme.color0

                Text {
                    anchors.centerIn: parent
                    text: isMuted ? "🔇" : (volumeLevel < 33 ? "🔈" : (volumeLevel < 66 ? "🔉" : "🔊"))
                    font.pixelSize: 16
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Process.start("wpctl", ["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                        refresh()
                    }
                }
            }

            Row {
                height: parent.height
                spacing: 8

                Rectangle {
                    width: 140
                    height: 6
                    y: parent.height / 2 - 3
                    radius: 3
                    color: Theme.color0

                    Rectangle {
                        width: isMuted ? 0 : (volumeLevel / 100 * 140)
                        height: 6
                        radius: 3
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        onMouseXChanged: (mouse) => {
                            if (mouse.x >= 0 && mouse.x <= 140) {
                                const newVol = Math.round(mouse.x / 140 * 100)
                                Process.start("wpctl", ["set-volume", "@DEFAULT_AUDIO_SINK@", `${newVol / 100}`])
                                refresh()
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: volumeLevel + "%"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }
    }

    function toggle(item) {
        visible = !visible
        if (visible) {
            refresh()
            reposition(item)
        }
    }
}
