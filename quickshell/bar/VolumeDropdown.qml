import QtQuick
import Quickshell.Panels
import Quickshell.Services.Audio

PopupWindow {
    id: volumeDropdown
    width: 240
    height: 60
    anchor: PopupWindow.TopEdge
    margin: 4
    visible: false
    closePolicy: PopupWindow.ClickOutside | PopupWindow.Escape

    AudioDevice {
        id: defaultSink
    }

    Row {
        anchors.fill: parent
        padding: Theme.padding
        spacing: 12

        // Mute button
        Rectangle {
            width: 36
            height: 36
            radius: Theme.radius
            color: defaultSink.muted ? Theme.accent : Theme.color0

            Text {
                anchors.centerIn: parent
                text: defaultSink.muted ? "🔇" : (defaultSink.volume < 33 ? "🔈" : (defaultSink.volume < 66 ? "🔉" : "🔊"))
                font.pixelSize: 16
            }

            MouseArea {
                anchors.fill: parent
                onClicked: defaultSink.muted = !defaultSink.muted
            }
        }

        // Volume slider
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
                    width: defaultSink.volume / 100 * 140
                    height: 6
                    radius: 3
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    onMouseXChanged: {
                        if (mouseArea.mouseY >= -10 && mouseArea.mouseY <= 16) {
                            defaultSink.volume = Math.round(mouseX / 140 * 100)
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: defaultSink.volume + "%"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }

    function toggle() {
        visible = !visible
    }
}
