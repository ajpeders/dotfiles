import QtQuick
import Quickshell.Services.Audio

Item {
    id: volume
    property int barHeight: 34
    width: 50

    // PulseAudio/PipeWire volume
    AudioDevice {
        id: defaultSink
        // Use default sink
    }

    function getIcon() {
        if (defaultSink.muted) return "🔇"
        const vol = defaultSink.volume
        if (vol <= 0) return "🔇"
        if (vol < 33) return "🔈"
        if (vol < 66) return "🔉"
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

    // Scroll to adjust volume
    WheelEventListener {
        anchors.fill: parent
        onWheel: (event) => {
            const delta = event.angleDelta.y > 0 ? 5 : -5
            defaultSink.volume = Math.max(0, Math.min(100, defaultSink.volume + delta))
        }
    }
}
