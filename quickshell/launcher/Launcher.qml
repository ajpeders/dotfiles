import QtQuick
import Quickshell
import Quickshell.Panels

PanelWindow {
    id: launcher
    anchor: PanelWindow.Fullscreen
    visible: false
    layer: PanelWindow.Above
    focusable: true

    // Dimmed backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: 0.7
    }

    // Search overlay
    Rectangle {
        anchors.centerIn: parent
        width: 600
        height: 500
        radius: Theme.radius
        color: Theme.panelBg

        Column {
            anchors.fill: parent
            padding: Theme.padding
            spacing: Theme.padding

            // Search box
            Rectangle {
                id: searchBox
                width: parent.width
                height: 40
                radius: Theme.radius
                color: Theme.color0
                border.color: Theme.accent
                border.width: 1

                Row {
                    anchors.fill: parent
                    padding: 8
                    spacing: 8

                    Text { anchors.verticalCenter: parent.verticalCenter; text: "🔍"; font.pixelSize: 16 }
                    TextInput {
                        id: searchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 30
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        focus: true
                        onTextChanged: filterApps()
                    }
                }
            }

            // App grid
            ListView {
                id: appList
                width: parent.width
                height: parent.height - 40 - Theme.padding
                clip: true

                model: filteredApps

                delegate: Rectangle {
                    width: appList.width
                    height: 48
                    radius: Theme.radius
                    color: Theme.color0
                    opacity: 0.5

                    Row {
                        anchors.fill: parent
                        padding: 8
                        spacing: 12

                        Image {
                            width: 32
                            height: 32
                            source: model.icon || ""
                            fillMode: Image.PreserveAspectFit
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text { text: model.name; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                            Text { text: model.comment || ""; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: launchApp(model)
                    }
                }
            }
        }
    }

    property var allApps: []
    property var filteredApps: []

    function loadApps() {
        // Parse .desktop files from XDG paths
        // For now, populate with placeholder structure
        allApps = []
        filteredApps = allApps
    }

    function filterApps() {
        const query = searchInput.text.toLowerCase()
        if (query === "") {
            filteredApps = allApps.slice(0, 20) // top 20 by recency
            return
        }
        filteredApps = allApps.filter(app =>
            app.name.toLowerCase().includes(query) ||
            (app.comment && app.comment.toLowerCase().includes(query))
        )
    }

    function launchApp(app) {
        Process.start("gtk-launch", [app.id])
        launcher.visible = false
    }

    Component.onCompleted: {
        loadApps()
        launcher.visible = true
    }

    // Keyboard navigation
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) launcher.visible = false
        if (event.key === Qt.Key_Return && filteredApps.length > 0) launchApp(filteredApps[0])
    }
}
