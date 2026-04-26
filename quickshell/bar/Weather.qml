import QtQuick

Item {
    id: weather
    property int barHeight: 34
    width: 60

    property string temp: "--"
    property string condition: ""
    property string location: ""

    Timer {
        id: refreshTimer
        interval: 30 * 60 * 1000 // 30 minutes
        repeat: true
        onTriggered: fetchWeather()
    }

    Component.onCompleted: {
        fetchWeather()
        refreshTimer.start()
    }

    function fetchWeather() {
        // Spawn wttr.in process — simplified inline
        process.start("curl", ["-s", "wttr.in/?format=%c%t+%l"])
        process.onFinished.connect((exitCode) => {
            if (exitCode !== 0) return
            const output = process.read()
            // Format: "☀️ 23°C New York"
            const parts = output.trim().split(' ')
            if (parts.length >= 2) {
                condition = parts[0]
                temp = parts[1]
                location = parts.slice(2).join(' ')
            }
        })
    }

    Process {
        id: process
    }

    Row {
        height: barHeight
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: condition
            font.pixelSize: 14
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: temp
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }

    ToolTip {
        text: location ? `${condition}${temp} — ${location}` : `${condition}${temp}`
    }
}
