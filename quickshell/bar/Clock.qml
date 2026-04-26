import QtQuick

Item {
    id: clock
    property int barHeight: 34
    width: clockText.width + padding * 2
    property int padding: Theme.padding

    Rectangle {
        id: clockBtn
        anchors.fill: parent
        radius: Theme.radius
        color: mouseArea.containsMouse ? Theme.color0 : "transparent"
        opacity: mouseArea.containsMouse ? 0.5 : 1.0
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        text: new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: calendarDropdown.toggle(clock)
    }

    CalendarDropdown {
        id: calendarDropdown
    }

    Timer {
        interval: 1000
        repeat: true
        onTriggered: clockText.text = new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
    }
}
