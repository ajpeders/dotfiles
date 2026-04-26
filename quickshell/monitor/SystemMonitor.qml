import Quickshell
import Quickshell._Window
import QtQuick

FloatingWindow {
    id: sysMonitor
    width: 200
    height: 120
    visible: false
    focusable: true
    color: "transparent"
    movable: true

    // Position: top-right of primary screen by default
    x: Quickshell.screens[0].width - width - 10
    y: 50

    property int cpuUsage: 0
    property int ramUsage: 0
    property int gpuUsage: 0
    property bool gpuAvailable: true

    Process { id: cpuProc }
    Process { id: ramProc }
    Process { id: gpuProc }

    Timer {
        interval: 2000
        repeat: true
        onTriggered: {
            readCpu()
            readRam()
            if (gpuAvailable) readGpu()
        }
    }

    function readCpu() {
        cpuProc.start("bash", ["-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1"])
    }

    function readRam() {
        ramProc.start("bash", ["-c", "free | grep Mem | awk '{print int($3/$2 * 100)}'"])
    }

    function readGpu() {
        gpuProc.start("bash", ["-c", "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits || echo 0"])
    }

    Component.onCompleted: {
        readCpu()
        readRam()
        readGpu()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panelBg

        Column {
            anchors.fill: parent
            padding: Theme.padding
            spacing: 8

            MonitorRow { label: "CPU"; value: cpuUsage }
            MonitorRow { label: "RAM"; value: ramUsage }
            MonitorRow { label: "GPU"; value: gpuUsage; visible: gpuAvailable }
        }
    }
}

component MonitorRow := Rectangle {
    property string label: ""
    property int value: 0
    width: parent ? parent.width : 200
    height: 24
    radius: 4
    color: "transparent"

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
