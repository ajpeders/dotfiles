import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: osd
    visible: false
    implicitWidth: 320
    implicitHeight: 72
    color: "transparent"
    anchors.top: true
    margins.top: 48
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    property string label: ""
    readonly property bool active: label === "Dictation on"

    function showDictation(text) {
        const monitor = Hyprland.focusedMonitor
        const target = Quickshell.screens.find(s => monitor && s.name === monitor.name)
        if (!target) return
        screen = target
        label = text
        visible = true
        hideTimer.restart()
    }

    IpcHandler {
        target: "dictation"
        function display(text: string): void { osd.showDictation(text) }
    }

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: osd.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: osd.active ? "#1a3a1f" : Theme.background
        border.color: osd.active ? "#7ec699" : Theme.panelBorder
        border.width: 2
        radius: 0

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            spacing: 14

            Rectangle {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: osd.active ? "#7ec699" : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.5)
            }

            Text {
                text: osd.label
                color: osd.active ? "#a8e6b9" : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 22
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
