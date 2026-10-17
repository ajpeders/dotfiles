import QtQuick

Rectangle {
    property alias text: buttonLabel.text
    signal clicked()
    height: Math.max(32, buttonLabel.implicitHeight + 12)
    radius: 0
    border.width: 1
    border.color: Theme.foreground
    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b,
                   buttonMouse.containsMouse ? 0.18 : 0.08)
    opacity: enabled ? 1 : 0.5

    Text {
        id: buttonLabel
        anchors.centerIn: parent
        width: parent.width - 12
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: Theme.foreground
        font.family: Theme.regularFontFamily
        font.pixelSize: 16
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: parent.clicked()
    }
}
