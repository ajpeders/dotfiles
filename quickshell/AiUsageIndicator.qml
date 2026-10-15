import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: indicator
    required property string providerId
    required property string providerName
    required property string iconName
    required property var selection
    readonly property alias popupWindow: details
    width: content.implicitWidth
    height: 30

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Item {
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: logo
                anchors.fill: parent
                source: Quickshell.shellPath("icons/" + indicator.iconName + ".svg")
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 1 // SVG paths are black; make them white before applying the tint.
                    colorization: 1
                    colorizationColor: Theme.foreground
                }
            }
        }

        Text {
            text: AIUsage.reading(indicator.providerId, 18000)
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.bold: true
        }

        Rectangle {
            width: 4
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * Math.max(0, AIUsage.percent(indicator.providerId, 604800)) / 100
                color: Theme.foreground
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: indicator.selection.togglePanel(indicator.providerId)
    }

    PopupWindow {
        id: details
        anchor.item: indicator
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.FlipX | PopupAdjustment.SlideX
        anchor.margins.bottom: 0
        visible: indicator.selection.activePanel === indicator.providerId
        implicitWidth: 360
        implicitHeight: 136
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
                    text: indicator.providerName
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                }
                Repeater {
                    model: [
                        { label: "Session", seconds: 18000 },
                        { label: "Weekly", seconds: 604800 }
                    ]
                    Column {
                        required property var modelData
                        spacing: 0
                        Text {
                            text: modelData.label + "  " + AIUsage.reading(indicator.providerId, modelData.seconds)
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Text {
                            width: 340
                            wrapMode: Text.WordWrap
                            text: AIUsage.metric(indicator.providerId, modelData.seconds)?.detail || "Usage unavailable"
                            color: Theme.foreground
                            font.family: Theme.regularFontFamily
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
