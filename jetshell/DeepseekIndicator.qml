import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: indicator
    required property var selection
    visible: AIUsage.shown("deepseek")
    width: visible ? content.implicitWidth : 0
    height: 30

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Image {
            id: logo
            width: 20
            height: 20
            source: Quickshell.shellPath("icons/deepseek.svg")
            anchors.verticalCenter: parent.verticalCenter
            layer.enabled: true
            layer.effect: MultiEffect {
                brightness: 1 // SVG paths are black; make them white before applying the tint.
                colorization: 1
                colorizationColor: Theme.foreground
            }
        }
        Text {
            text: AIUsage.deepseekBalance
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.bold: false
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: indicator.selection.togglePanel("ai-usage")
    }
}
