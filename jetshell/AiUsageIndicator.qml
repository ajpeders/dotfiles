import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: indicator
    required property string providerId
    required property var selection
    // Brand marks are looked up by vendor id; unknown vendors render without one.
    readonly property string iconName: AIUsage.iconName(indicator.providerId)
    readonly property int secondaryPercent: AIUsage.percentOf(AIUsage.secondary(indicator.providerId))
    width: content.implicitWidth
    height: 30
    visible: AIUsage.shown(indicator.providerId)

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Item {
            width: indicator.iconName !== "" ? 20 : 0
            height: 20
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: indicator.iconName !== ""
                        ? Quickshell.shellPath("icons/" + indicator.iconName + ".svg") : ""
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
            text: AIUsage.reading(indicator.providerId)
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.bold: false
        }

        // The vendor's slowest-moving window, when it reports more than one.
        Rectangle {
            visible: indicator.secondaryPercent >= 0
            width: 4
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)
            border.color: Theme.foreground
            border.width: 1

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2
                height: (parent.height - 2) * Math.max(0, indicator.secondaryPercent) / 100
                color: Theme.foreground
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: indicator.selection.togglePanel("ai-usage")
    }
}
