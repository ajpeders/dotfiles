import Quickshell
import Quickshell._Window
import QtQuick

FloatingWindow {
    id: brightnessOsd
    width: 300
    height: 50
    x: (Quickshell.screens[0].width - width) / 2
    y: (Quickshell.screens[0].height - height) / 2
    visible: false
    focusable: false
    color: "transparent"

    property int brightness: 100
    property int maxBrightness: 100

    function show() {
        visible = true
        readBrightness()
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: brightnessOsd.visible = false
    }

    Process {
        id: brightnessReader
        onFinished: (code) => {
            if (code !== 0) return
            const val = parseInt(brightnessReader.read().trim())
            if (!isNaN(val)) {
                brightness = val
                // Get max from brightnessctl
                brightnessReader2.start("brightnessctl", ["max"])
            }
        }
    }

    Process {
        id: brightnessReader2
        onFinished: (code) => {
            if (code !== 0) return
            const val = parseInt(brightnessReader2.read().trim())
            if (!isNaN(val) && val > 0) maxBrightness = val
        }
    }

    function readBrightness() {
        brightnessReader.start("brightnessctl", ["get"])
    }

    OpacityAnimator {
        id: fadeAnim
        target: brightnessOsd
        from: 0
        to: 1
        duration: Theme.animDuration
    }

    Rectangle {
        anchors.fill: parent
        radius: 25
        color: Theme.panelBg

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
                    width: (brightness / Math.max(maxBrightness, 1)) * 200
                    height: 6
                    radius: 3
                    color: Theme.accent
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round((brightness / Math.max(maxBrightness, 1)) * 100) + "%"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }

    onVisibleChanged: {
        if (visible) fadeAnim.start()
    }
}
