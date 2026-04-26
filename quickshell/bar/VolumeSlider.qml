import QtQuick
import QtQuick.Process
import QtQml

Item {
    id: volume
    property int barHeight: 34
    width: 50

    // Use wpctl for volume — AudioDevice not available in Quickshell Pipewire module
    property int volumeLevel: 100
    property bool isMuted: false

    Process {
        id: volumeReader
        onFinished: (code) => {
            if (code !== 0) return
            parseVolume(process.read())
        }
    }

    function parseVolume(output) {
        // wpctl get-volume @DEFAULT_AUDIO_SINK@ returns: "Volume: 0.50"
        const match = output.match(/Volume:\s*([\d.]+)/)
        if (match) {
            volumeLevel = Math.round(parseFloat(match[1]) * 100)
        }
        isMuted = output.includes("Muted")
    }

    function refreshVolume() {
        volumeReader.start("wpctl", ["get-volume", "@DEFAULT_AUDIO_SINK@"])
    }

    Component.onCompleted: refreshVolume()

    function getIcon() {
        if (isMuted) return "🔇"
        if (volumeLevel <= 0) return "🔇"
        if (volumeLevel < 33) return "🔈"
        if (volumeLevel < 66) return "🔉"
        return "🔊"
    }

    Text {
        anchors.centerIn: parent
        text: getIcon()
        font.pixelSize: 14
    }

    MouseArea {
        anchors.fill: parent
        onClicked: volumeDropdown.toggle()
    }

    VolumeDropdown {
        id: volumeDropdown
        anchors.top: parent.bottom
        x: parent.width / 2 - width / 2
    }

    WheelEventListener {
        anchors.fill: parent
        onWheel: (event) => {
            const delta = event.angleDelta.y > 0 ? 5 : -5
            const newVol = Math.max(0, Math.min(100, volumeLevel + delta))
            Process.start("wpctl", ["set-volume", "@DEFAULT_AUDIO_SINK@", `${newVol / 100}`])
            refreshVolume()
        }
    }
}
