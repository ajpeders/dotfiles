import QtQuick

Item {
    id: qsButton
    property int barHeight: 34
    width: 30

    Rectangle {
        id: btn
        anchors.fill: parent
        radius: Theme.radius
        color: mouseArea.containsHover ? Theme.color0 : "transparent"
        opacity: mouseArea.containsHover ? 0.5 : 1.0

        Text {
            anchors.centerIn: parent
            text: "⚙"
            font.pixelSize: 14
            color: Theme.foreground
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: app.showQuickSettings()
    }
}
