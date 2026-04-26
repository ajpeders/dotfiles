import QtQuick
import Quickshell
import Quickshell.Panels

PanelWindow {
    id: brightnessOsd
    anchor: PanelWindow.Center
    width: 300
    height: 50
    margin: 0
    visible: false
    layer: PanelWindow.Above
    blockGestures: true
    focusable: false

    OpacityAnimator {
        id: fadeAnim
        target: brightnessOsd
        from: 0
        to: 1
        duration: Theme.animDuration
    }

    // Brightness via brightnessctl
    property int brightness: 100
    property int maxBrightness: 100

    Process {
        id: brightnessReader
        onFinished: (exitCode) => {
            if (exitCode !== 0) return
            const val = parseInt(brightnessReader.read().trim())
            if (!isNaN(val)) {
                brightness = val
                maxBrightness = brightnessReader.read().trim() || 100
            }
        }
    }

    function readBrightness() {
        brightnessReader.start("brightnessctl", ["get"])
    }

    Rectangle {
        anchors.fill: parent
        radius: 25
        color: Theme.panelBg
        opacity: 0.9

        Row {
            anchors.fill: parent
            padding: 12
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "☀️"
                font.pixelSize: 20
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 200
                height: 6
                radius: 3
                color: Theme.color0

                Rectangle {
                    width: (brightness / maxBrightness) * 200
                    height: 6
                    radius: 3
                    color: Theme.accent
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round((brightness / maxBrightness) * 100) + "%"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            readBrightness()
            fadeAnim.start()
        }
    }
}
