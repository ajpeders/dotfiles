import QtQuick
import Quickshell.Panels
import Quickshell.Services.Mpris

PopupWindow {
    id: mediaPopup
    width: 320
    height: 120
    anchor: PopupWindow.TopEdge
    margin: 4
    closePolicy: PopupWindow.ClickOutside | PopupWindow.Escape

    MprisPlayer {
        id: mpris
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panelBg

        Row {
            anchors.fill: parent
            padding: Theme.padding
            spacing: 12

            // Album art
            Rectangle {
                width: 80
                height: 80
                radius: Theme.radius
                color: Theme.color0

                Image {
                    anchors.fill: parent
                    source: mpris.artUrl || ""
                    fillMode: Image.PreserveAspectCrop
                    visible: mpris.artUrl !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: "🎵"
                    font.pixelSize: 28
                    visible: mpris.artUrl === ""
                }
            }

            // Track info + controls
            Column {
                width: parent.width - 80 - Theme.padding
                height: 80
                spacing: 4

                // Title + artist
                Column {
                    width: parent.width
                    spacing: 2

                    Text {
                        text: mpris.trackTitle || "Nothing playing"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        text: mpris.artist || ""
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // Progress bar
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.color0

                    Rectangle {
                        width: (mpris.position / (mpris.length || 1)) * parent.width
                        height: 4
                        radius: 2
                        color: Theme.accent
                    }
                }

                // Transport controls
                Row {
                    height: 28
                    spacing: 8

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: Theme.color0
                        Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 12; color: Theme.foreground }
                        MouseArea { anchors.fill: parent; onClicked: mpris.previous() }
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: Theme.accent
                        Text { anchors.centerIn: parent; text: mpris.playbackStatus === Mpris.Playing ? "⏸" : "▶"; font.pixelSize: 12; color: Theme.background }
                        MouseArea { anchors.fill: parent; onClicked: { if (mpris.playbackStatus === Mpris.Playing) mpris.pause() else mpris.play() } }
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: Theme.color0
                        Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 12; color: Theme.foreground }
                        MouseArea { anchors.fill: parent; onClicked: mpris.next() }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: mpris.sourceName || ""
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }
}
