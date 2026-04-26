import QtQuick

Item {
    width: 60
    height: parent.height

    Text {
        id: clockText
        anchors.centerIn: parent
        text: new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
        color: "#cdd6f4"
        font.family: "JetBrains Mono"
        font.pixelSize: 13
    }

    Timer {
        interval: 1000
        repeat: true
        onTriggered: clockText.text = new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
    }
}
