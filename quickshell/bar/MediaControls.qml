import QtQuick
import Quickshell.Services.Mpris

Item {
    id: media
    property int barHeight: 34
    width: 120

    // Mpris player
    MprisPlayer {
        id: mpris
        // Uses the most recent player if multiple exist
    }

    MouseArea {
        anchors.fill: parent
        onClicked: app.showMediaPopup()
    }

    Row {
        height: barHeight
        spacing: 4

        // Play/pause icon
        Rectangle {
            width: 24
            height: barHeight - 6
            y: 3
            radius: Theme.radius
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: mpris.playbackStatus === Mpris.Playing ? "⏸" : "▶"
                color: Theme.background
                font.pixelSize: 10
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (mpris.playbackStatus === Mpris.Playing) mpris.pause()
                    else mpris.play()
                }
            }
        }

        // Track info
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
