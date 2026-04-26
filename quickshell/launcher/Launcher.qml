import Quickshell
import Quickshell._Window
import QtQuick

FloatingWindow {
    id: launcher
    width: 600
    height: 500
    // Center on primary screen
    x: (Quickshell.screens[0].width - width) / 2
    y: (Quickshell.screens[0].height - height) / 2
    visible: false
    focusable: true
    color: "transparent"

    OpacityAnimator {
        id: fadeIn
        target: launcher
        from: 0
        to: 1
        duration: Theme.animDuration
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panelBg

        Column {
            anchors.fill: parent
            padding: Theme.padding
            spacing: Theme.padding

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
                            Text { text: model.name || ""; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                            Text { text: model.genericName || ""; color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
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
        // DesktopEntries.applications is pre-populated by Quickshell
        const apps = DesktopEntries.applications
        allApps = []
        for (let i = 0; i < apps.count; i++) {
            const app = apps.get(i)
            allApps.push({ id: app.id, name: app.name, genericName: app.genericName, icon: app.icon || "", exec: app.exec || "" })
        }
        filteredApps = allApps.slice(0, 20)
    }

    function filterApps() {
        const query = searchInput.text.toLowerCase()
        if (query === "") {
            filteredApps = allApps.slice(0, 20)
            return
        }
        filteredApps = allApps.filter(app =>
            (app.name && app.name.toLowerCase().includes(query)) ||
            (app.genericName && app.genericName.toLowerCase().includes(query))
        )
    }

    function launchApp(app) {
        Process.start("gtk-launch", [app.id])
        launcher.visible = false
    }

    onVisibleChanged: {
        if (visible) {
            loadApps()
            fadeIn.start()
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) launcher.visible = false
        if (event.key === Qt.Key_Return && filteredApps.length > 0) launchApp(filteredApps[0])
    }
}
