import QtQuick
import QtQuick.Controls
import Quickshell

Item {
    id: root
    required property var selection
    readonly property alias popupWindow: playerPopup
    implicitWidth: 300
    implicitHeight: 30
    readonly property string displayText: AudioPlayer.title
        ? (AudioPlayer.artist ? AudioPlayer.artist + " — " : "") + AudioPlayer.title
        : AudioPlayer.playing ? "Now playing" : ""

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
                width: 3
                height: Math.max(1, 22 * (AudioPlayer.freq[index] || 0))
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
                    if (viewport.overflow && AudioPlayer.player !== null) marquee.start()
                })
            }
        }

        SequentialAnimation {
            id: marquee
            running: viewport.overflow && AudioPlayer.player !== null
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
        cursorShape: Qt.PointingHandCursor
        onClicked: root.selection.togglePanel("player")
    }

    Item {
        id: playerAnchor
        x: visualizer.x
        height: root.height
        width: 1
    }

    PopupWindow {
        id: playerPopup
        anchor.item: playerAnchor
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.SlideX
        visible: root.selection.activePanel === "player" && AudioPlayer.player !== null
        implicitWidth: Math.min(320, root.selection.screen.width - 16)
        implicitHeight: playerContent.implicitHeight + 24
        color: Theme.background

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border.color: Theme.panelBorder
            border.width: 1
        }

        Column {
            id: playerContent
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Row {
                width: parent.width
                height: 76
                spacing: 10

                Rectangle {
                    width: 76
                    height: 76
                    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: cover.status !== Image.Ready
                        text: "♫"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 32
                    }

                    Image {
                        id: cover
                        anchors.fill: parent
                        source: AudioPlayer.player ? AudioPlayer.player.trackArtUrl : ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                }

                Column {
                    id: infoColumn
                    width: parent.width - 86
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    function secsToString(s) {
                        if (!isFinite(s) || s <= 0) return "0:00"
                        const total = Math.floor(s)
                        const m = Math.floor(total / 60)
                        const sec = total % 60
                        return m + ":" + (sec < 10 ? "0" : "") + sec
                    }

                    readonly property string timeText: {
                            if (!(AudioPlayer.player && AudioPlayer.player.positionSupported)) return "--:-- / --:--"
                            let pos = AudioPlayer.player.position
                            let end = AudioPlayer.player.lengthSupported ? AudioPlayer.player.length : 0
                            if (progressBar.scrubFraction >= 0 && end > 0)
                                pos = progressBar.scrubFraction * end
                            return secsToString(pos) + " / " + (end > 0 ? secsToString(end) : "--:--")
                        }

                    Text {
                        width: parent.width
                        text: AudioPlayer.title || "Now playing"
                        elide: Text.ElideRight
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                    }

                    Text {
                        width: parent.width
                        text: AudioPlayer.artist
                        elide: Text.ElideRight
                        color: Theme.foreground
                        font.family: Theme.regularFontFamily
                        font.pixelSize: 16
                    }

                    Text {
                        width: parent.width
                        text: infoColumn.timeText
                        color: Theme.foreground
                        opacity: 0.7
                        font.family: Theme.regularFontFamily
                        font.pixelSize: 14
                    }
                }
            }

            Timer {
                id: positionTimer
                interval: 500
                running: !!AudioPlayer.player && AudioPlayer.player.isPlaying
                repeat: true
                onTriggered: { if (AudioPlayer.player) AudioPlayer.player.positionChanged() }
            }

            Rectangle {
                id: progressBar
                width: parent.width
                height: 16
                color: "transparent"

                readonly property real len: !!AudioPlayer.player && AudioPlayer.player.lengthSupported
                                            ? AudioPlayer.player.length : 0
                readonly property bool seekable: !!AudioPlayer.player && AudioPlayer.player.canSeek && len > 0
                readonly property real liveFraction: (!!AudioPlayer.player && AudioPlayer.player.lengthSupported
                                                      && AudioPlayer.player.positionSupported)
                                                     ? Math.min(Math.max(AudioPlayer.player.position / Math.max(len, 0.1), 0), 1)
                                                     : 0
                // While scrubbing, the fill follows the pointer instead of the
                // player's own position tick, which lags behind during a drag.
                property real scrubFraction: -1
                readonly property real fraction: scrubFraction >= 0 ? scrubFraction : liveFraction

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * progressBar.fraction
                        color: Theme.foreground
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * progressBar.fraction - width / 2
                        width: hoverable.containsMouse || hoverable.pressed ? 10 : 6
                        height: width
                        radius: width / 2
                        color: Theme.foreground
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }
                }

                MouseArea {
                    id: hoverable
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function fracAt(x) {
                        return Math.min(Math.max(x / width, 0), 1)
                    }

                    onPositionChanged: mouse => {
                        if (pressed && progressBar.seekable)
                            progressBar.scrubFraction = fracAt(mouse.x)
                    }
                    onPressed: mouse => {
                        if (!progressBar.seekable) return
                        progressBar.scrubFraction = fracAt(mouse.x)
                        AudioPlayer.player.position = progressBar.scrubFraction * progressBar.len
                    }
                    onReleased: mouse => {
                        if (progressBar.seekable && progressBar.scrubFraction >= 0)
                            AudioPlayer.player.position = progressBar.scrubFraction * progressBar.len
                        progressBar.scrubFraction = -1
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8

                AudioButton {
                    width: (parent.width - 32) / 5
                    text: "-10s"
                    enabled: !!AudioPlayer.player && AudioPlayer.player.canSeek
                    onClicked: AudioPlayer.player.seek(-10)
                }
                AudioButton {
                    width: (parent.width - 32) / 5
                    text: "Prev"
                    enabled: !!AudioPlayer.player && AudioPlayer.player.canGoPrevious
                    onClicked: AudioPlayer.player.previous()
                }
                AudioButton {
                    width: (parent.width - 32) / 5
                    text: AudioPlayer.playing ? "Pause" : "Play"
                    enabled: !!AudioPlayer.player && AudioPlayer.player.canTogglePlaying
                    onClicked: AudioPlayer.player.togglePlaying()
                }
                AudioButton {
                    width: (parent.width - 32) / 5
                    text: "Next"
                    enabled: !!AudioPlayer.player && AudioPlayer.player.canGoNext
                    onClicked: AudioPlayer.player.next()
                }
                AudioButton {
                    width: (parent.width - 32) / 5
                    text: "+10s"
                    enabled: !!AudioPlayer.player && AudioPlayer.player.canSeek
                    onClicked: AudioPlayer.player.seek(10)
                }
            }

            Row {
                width: parent.width
                height: 28
                spacing: 8

                Text {
                    text: "Player volume"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.foreground
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 16
                }

                Slider {
                    id: volumeSlider
                    width: parent.width - 160
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: 1
                    enabled: !!AudioPlayer.player && AudioPlayer.player.volumeSupported
                    value: enabled ? AudioPlayer.player.volume : 0
                    onMoved: AudioPlayer.player.volume = value

                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                        width: volumeSlider.availableWidth
                        height: 4
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)

                        Rectangle {
                            width: volumeSlider.visualPosition * parent.width
                            height: parent.height
                            color: Theme.foreground
                        }
                    }

                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                        width: 10
                        height: 16
                        color: Theme.foreground
                    }
                }

                Text {
                    text: AudioPlayer.player && AudioPlayer.player.volumeSupported
                          ? Math.round(AudioPlayer.player.volume * 100) + "%" : "--%"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                }
            }
        }
    }
}
