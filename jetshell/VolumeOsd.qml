import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PanelWindow {
    id: osd
    visible: false
    implicitWidth: 260
    implicitHeight: 68
    color: "transparent"
    anchors.top: true
    margins.top: 48
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

    function showVolume() {
        const monitor = Hyprland.focusedMonitor
        const target = Quickshell.screens.find(s => monitor && s.name === monitor.name)
        if (!target || !audio) return
        screen = target
        visible = true
        hideTimer.restart()
    }

    IpcHandler {
        target: "volume"
        function display(): void { osd.showVolume() }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: osd.audio
        function onVolumeChanged() {
            if (!VolumeOsdState.isSuppressed()) osd.showVolume()
        }
        function onMutedChanged() {
            if (!VolumeOsdState.isSuppressed()) osd.showVolume()
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        border.color: Theme.panelBorder
        border.width: 1
        radius: 0

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 10
            text: !osd.audio ? "No audio" : osd.audio.muted ? "Muted"
                  : "Volume  " + Math.round(osd.audio.volume * 100) + "%"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 18
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            height: 8
            color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)

            Rectangle {
                width: parent.width * (osd.audio && !osd.audio.muted
                       ? Math.max(0, Math.min(1, osd.audio.volume)) : 0)
                height: parent.height
                color: Theme.foreground
            }
        }
    }
}
