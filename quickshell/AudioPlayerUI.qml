import QtQuick
import Quickshell

Item {
    id: root
    required property var selection
    implicitWidth: 300
    implicitHeight: 30
    readonly property string displayText: AudioPlayer.title
        ? (AudioPlayer.artist ? AudioPlayer.artist + " — " : "") + AudioPlayer.title
        : ""

    Row {
        id: visualizer
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        spacing: 1

        Repeater {
            model: 24
            Rectangle {
                required property int index
                width: 2
                height: Math.max(1, 22 * (AudioPlayer.playing ? AudioPlayer.freq[index] || 0 : 0))
                anchors.bottom: parent.bottom
                color: Theme.foreground
                opacity: AudioPlayer.playing ? 0.85 : 0.3
                Behavior on height { NumberAnimation { duration: 150 } }
            }
        }
    }

    Item {
        id: viewport
        anchors.left: visualizer.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        height: parent.height
        clip: true
        readonly property bool overflow: track.implicitWidth > width

        Text {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            text: root.displayText
            color: Theme.foreground
            opacity: AudioPlayer.title ? 1 : 0.5
            font.family: Theme.regularFontFamily
            font.pixelSize: 20
            onTextChanged: {
                marquee.stop()
                x = 0
                Qt.callLater(() => {
                    if (viewport.overflow && AudioPlayer.playing) marquee.start()
                })
            }
        }

        SequentialAnimation {
            id: marquee
            running: viewport.overflow && AudioPlayer.playing
            loops: Animation.Infinite
            PauseAnimation { duration: 1200 }
            NumberAnimation {
                target: track
                property: "x"
                from: 0
                to: Math.min(0, viewport.width - track.implicitWidth)
                duration: Math.max(1000, (track.implicitWidth - viewport.width) * 35)
            }
            PauseAnimation { duration: 1200 }
            PropertyAction { target: track; property: "x"; value: 0 }
            onStopped: track.x = 0
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: AudioPlayer.player !== null && AudioPlayer.player.canTogglePlaying
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.selection.dismissPanels()
            AudioPlayer.player.togglePlaying()
        }
    }
}
