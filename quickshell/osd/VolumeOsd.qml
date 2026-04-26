import QtQuick
import Quickshell
import Quickshell.Panels
import Quickshell.Services.Audio

PanelWindow {
    id: volumeOsd
    anchor: PanelWindow.Center
    width: 300
    height: 50
    margin: 0
    visible: false
    layer: PanelWindow.Above
    blockGestures: true
    focusable: false

    // Fades in/out with animation
    OpacityAnimator {
        id: fadeAnim
        target: volumeOsd
        from: 0
        to: 1
        duration: Theme.animDuration
    }

    AudioDevice {
        id: defaultSink
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

            // Speaker icon
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: defaultSink.muted ? "🔇" : (defaultSink.volume < 33 ? "🔈" : (defaultSink.volume < 66 ? "🔉" : "🔊"))
                font.pixelSize: 20
            }

            // Volume bar
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 200
                height: 6
                radius: 3
                color: Theme.color0

                Rectangle {
                    width: defaultSink.muted ? 0 : (defaultSink.volume / 100 * 200)
                    height: 6
                    radius: 3
                    color: Theme.accent
                }
            }

            // Percentage
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: defaultSink.volume + "%"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }

    // Watch app volumeOsdVisible
    onVisibleChanged: {
        if (visible) fadeAnim.start()
    }
}
