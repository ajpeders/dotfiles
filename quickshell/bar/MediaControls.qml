import QtQuick
import Quickshell.Services.Mpris

Item {
    id: media
    property int barHeight: 34
    width: 120
    signal openMedia()

    MprisPlayer {
        id: mpris
    }

    MouseArea {
        anchors.fill: parent
        onClicked: openMedia()
    }

    Row {
        height: barHeight
        spacing: 4

        Rectangle {
            width: 24
            height: barHeight - 6
            y: 3
            radius: Theme.radius
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: mpris.playbackStatus === Mpris.PlaybackState.Playing ? "⏸" : "▶"
                color: Theme.background
                font.pixelSize: 10
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (mpris.playbackStatus === Mpris.PlaybackState.Playing) mpris.pause()
                    else mpris.play()
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: mpris.trackTitle || "Nothing playing"
            color: mpris.trackTitle ? Theme.foreground : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
            maximumLineCount: 1
            width: 90
        }
    }
}
