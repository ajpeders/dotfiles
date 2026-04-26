import Quickshell
import QtQuick

PanelWindow {
    anchors { top: true; left: true; right: true }
    implicitHeight: 34
    color: "#1a1a2e"

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Quickshell"
            color: "#cdd6f4"
            font.family: "JetBrains Mono"
            font.pixelSize: 14
        }

        Item { Layout.fillWidth: true }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
            color: "#cdd6f4"
            font.family: "JetBrains Mono"
            font.pixelSize: 14
        }
    }

    // Update clock every second
    Timer {
        interval: 1000
        repeat: true
        onTriggered: { }
    }
}
