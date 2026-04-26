import QtQuick
import Quickshell
import Quickshell.Panels

PanelWindow {
    id: sysMonitor
    width: 200
    height: 120
    margin: 10
    layer: PanelWindow.Above
    movable: true
    focusable: true

    // Position persisted via Quickshell state

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panelBg

        Column {
            anchors.fill: parent
            padding: Theme.padding
            spacing: 8

            // CPU
            MonitorRow {
                label: "CPU"
                value: cpuUsage
                onValueChanged: cpuUsage = readCpu()
            }

            // RAM
            MonitorRow {
                label: "RAM"
                value: ramUsage
                onValueChanged: ramUsage = readRam()
            }

            // GPU (if available)
            MonitorRow {
                label: "GPU"
                value: gpuUsage
                visible: gpuAvailable
                onValueChanged: gpuUsage = readGpu()
            }
        }
    }

    property int cpuUsage: 0
    property int ramUsage: 0
    property int gpuUsage: 0
    property bool gpuAvailable: false

    Timer {
        interval: 2000
        repeat: true
        onTriggered: {
            cpuUsage = readCpu()
            ramUsage = readRam()
            if (gpuAvailable) gpuUsage = readGpu()
        }
    }

    function readCpu() {
        // Read /proc/stat for cpu usage — simplified
        return 0 // implement with Process reading /proc/stat
    }

    function readRam() {
        // Read /proc/meminfo — simplified
        return 0
    }

    function readGpu() {
        // Check nvidia-smi first, then amd sysfs — simplified
        return 0
    }

    function detectGpu() {
        // Check /sys/class/drm for AMD, nvidia-smi for NVIDIA
        gpuAvailable = true // implement detection
    }

    Component.onCompleted: detectGpu()
}

Component {
    id: MonitorRow

    Rectangle {
        width: parent ? parent.width : 200
        height: 24
        radius: 4
        color: "transparent"

        property string label: ""
        property int value: 0

        Row {
            anchors.fill: parent
            spacing: 8

            Text {
                width: 36
                anchors.verticalCenter: parent.verticalCenter
                text: label
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 100
                height: 6
                radius: 3
                color: Theme.color0

                Rectangle {
                    width: (value / 100) * 100
                    height: 6
                    radius: 3
                    color: Theme.accent
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: value + "%"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
