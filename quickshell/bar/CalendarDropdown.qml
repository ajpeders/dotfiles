import Quickshell
import Quickshell._Window
import QtQuick

FloatingWindow {
    id: calendarDropdown
    width: 280
    height: 300
    visible: false
    focusable: true
    color: "transparent"

    // Position: below the clock, centered
    property var targetItem: null

    function reposition(item) {
        if (!item) return
        const rect = item.window.itemRect(item)
        x = rect.x + rect.width / 2 - width / 2
        y = rect.y + rect.height
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panelBg

        Column {
            anchors.fill: parent
            padding: Theme.padding
            spacing: 4

            // Month navigation
            Row {
                width: parent.width
                height: 30
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: new Date(currentYear, currentMonth, 1).toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Item { Layout.fillWidth: true; height: 1 }

                Rectangle {
                    width: 24
                    height: 24
                    radius: Theme.radius
                    color: Theme.color0
                    Text { anchors.centerIn: parent; text: "◀"; color: Theme.foreground; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; onClicked: { if (currentMonth === 0) { currentMonth = 11; currentYear-- } else currentMonth-- } }
                }
                Rectangle {
                    width: 24
                    height: 24
                    radius: Theme.radius
                    color: Theme.color0
                    Text { anchors.centerIn: parent; text: "▶"; color: Theme.foreground; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; onClicked: { if (currentMonth === 11) { currentMonth = 0; currentYear++ } else currentMonth++ } }
                }
            }

            // Day headers
            Row {
                width: parent.width
                spacing: 0
                Repeater {
                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    Text {
                        width: parent.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            Grid {
                id: dayGrid
                width: parent.width
                columns: 7
                spacing: 2
            }

            Component.onCompleted: buildCalendar()
        }
    }

    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()

    function buildCalendar() {
        dayGrid.model = []
        const firstDay = new Date(currentYear, currentMonth, 1).getDay()
        const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate()
        const today = new Date()
        for (let i = 0; i < firstDay; i++) dayGrid.model.append({ day: "", isToday: false })
        for (let d = 1; d <= daysInMonth; d++) {
            const isToday = d === today.getDate() && currentMonth === today.getMonth() && currentYear === today.getFullYear()
            dayGrid.model.append({ day: d, isToday })
        }
    }

    function toggle(item) {
        visible = !visible
        if (visible) reposition(item)
    }

    onCurrentMonthChanged: buildCalendar()
    onCurrentYearChanged: buildCalendar()
}
