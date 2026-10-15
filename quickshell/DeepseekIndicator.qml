import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: indicator
    required property var selection
    readonly property alias popupWindow: details
    visible: AIUsage.deepseekSpend !== ""
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
            text: AIUsage.deepseekSpend
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: indicator.selection.togglePanel("deepseek")
    }

    PopupWindow {
        id: details
        anchor.item: indicator
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.FlipX | PopupAdjustment.SlideX
        anchor.margins.bottom: 0
        visible: indicator.visible && indicator.selection.activePanel === "deepseek"
        implicitWidth: 340
        implicitHeight: 82
        color: Theme.background

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border.color: "#000000"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                Text {
                    text: "DeepSeek  " + AIUsage.deepseekSpend + " spent"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                }
                Text {
                    text: "OpenCode-tracked cost, not account balance."
                    color: Theme.foreground
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 16
                }
            }
        }
    }
}
