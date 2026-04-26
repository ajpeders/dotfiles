import Quickshell
import Quickshell._Window
import QtQuick

FloatingWindow {
    id: volumeOsd
    width: 300
    height: 50
    // Center on primary screen
    x: (Quickshell.screens[0].width - width) / 2
    y: (Quickshell.screens[0].height - height) / 2
    visible: false
    focusable: false
    color: "transparent"

    property int volumeLevel: 100
    property bool isMuted: false

    function show() {
        visible = true
        refreshVolume()
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: volumeOsd.visible = false
    }

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

    function refreshVolume() {
        volReader.start("wpctl", ["get-volume", "@DEFAULT_AUDIO_SINK@"])
    }

    OpacityAnimator {
        id: fadeAnim
        target: volumeOsd
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
                text: isMuted ? "🔇" : (volumeLevel < 33 ? "🔈" : (volumeLevel < 66 ? "🔉" : "🔊"))
                font.pixelSize: 20
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 200
                height: 6
                radius: 3
                color: Theme.color0

                Rectangle {
                    width: isMuted ? 0 : (volumeLevel / 100 * 200)
                    height: 6
                    radius: 3
                    color: Theme.accent
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: volumeLevel + "%"
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
