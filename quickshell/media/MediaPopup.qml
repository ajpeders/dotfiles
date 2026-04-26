import Quickshell
import Quickshell._Window
import Quickshell.Services.Mpris
import QtQuick

FloatingWindow {
    id: mediaPopup
    width: 320
    height: 120
    // Position: center of primary screen
    x: (Quickshell.screens[0].width - width) / 2
    y: 50
    visible: false
    focusable: true
    color: "transparent"

    MprisPlayer {
        id: mpris
    }

    OpacityAnimator {
        id: fadeIn
        target: mediaPopup
        from: 0
        to: 1
        duration: Theme.animDuration
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

            Column {
                width: parent.width - 80 - Theme.padding
                height: 80
                spacing: 4

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
                        Text {
                            anchors.centerIn: parent
                            text: mpris.playbackStatus === Mpris.PlaybackState.Playing ? "⏸" : "▶"
                            font.pixelSize: 12
                            color: Theme.background
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (mpris.playbackStatus === Mpris.PlaybackState.Playing) mpris.pause()
                                else mpris.play()
                            }
                        }
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

    onVisibleChanged: {
        if (visible) fadeIn.start()
    }

    function toggle() {
        visible = !visible
    }
}
