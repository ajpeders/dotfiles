import QtQuick
import Quickshell
import Quickshell.Hyprland

PanelWindow {
    id: launcher
    visible: false
    color: "transparent"
    implicitWidth: 540
    implicitHeight: 470
    anchors { top: true }
    margins.top: Math.max(40, Math.round((screen.height - implicitHeight) / 2))
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    property int selected: 0

    function typoDistance(a, b, limit) {
        if (Math.abs(a.length - b.length) > limit) return limit + 1
        const rows = Array.from({ length: a.length + 1 }, () => Array(b.length + 1).fill(0))
        for (let i = 0; i <= a.length; i++) rows[i][0] = i
        for (let j = 0; j <= b.length; j++) rows[0][j] = j
        for (let i = 1; i <= a.length; i++) {
            for (let j = 1; j <= b.length; j++) {
                rows[i][j] = Math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1,
                                      rows[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1))
                if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1])
                    rows[i][j] = Math.min(rows[i][j], rows[i - 2][j - 2] + 1)
            }
        }
        return rows[a.length][b.length]
    }

    function matchScore(term, value) {
        if (!value) return Infinity
        const text = value.toLowerCase()
        if (text === term) return 0
        if (text.startsWith(term)) return 10
        if (text.split(/[^\p{L}\p{N}]+/u).some(word => word.startsWith(term))) return 20
        if (text.includes(term)) return 30
        const limit = term.length >= 6 ? 2 : term.length >= 3 ? 1 : 0
        if (!limit) return Infinity
        let best = Infinity
        for (const word of text.split(/[^\p{L}\p{N}]+/u)) {
            if (word) best = Math.min(best, typoDistance(term, word, limit))
        }
        return best <= limit ? 50 + best * 10 : Infinity
    }

    function appScore(app, terms) {
        const fields = [[app.name, 0], [app.genericName, 15],
                        ...app.keywords.map(word => [word, 20]),
                        [app.id, 25], [app.comment, 40]]
        let total = 0
        for (const term of terms) {
            const best = Math.min(...fields.map(([value, weight]) => matchScore(term, value) + weight))
            if (!Number.isFinite(best)) return Infinity
            total += best
        }
        return total
    }

    readonly property var matches: {
        const query = search.text.trim().toLowerCase()
        const terms = query.split(/\s+/).filter(Boolean)
        return DesktopEntries.applications.values.map(app => ({ app, score: appScore(app, terms) }))
            .filter(result => Number.isFinite(result.score))
            .sort((a, b) => a.score - b.score || a.app.name.localeCompare(b.app.name))
            .map(result => result.app)
    }

    function open() {
        const monitor = Hyprland.focusedMonitor
        const target = Quickshell.screens.find(s => monitor && s.name === monitor.name)
        if (target) screen = target
        search.text = ""
        selected = 0
        visible = true
        grab.active = true
        Qt.callLater(() => search.forceActiveFocus())
    }

    function close() {
        grab.active = false
        visible = false
    }

    function launch(index) {
        if (index < 0 || index >= matches.length) return
        const app = matches[index]
        close()
        app.execute()
    }

    HyprlandFocusGrab {
        id: grab
        windows: [launcher]
        onCleared: launcher.close()
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Theme.background
        border.width: 4
        border.color: Theme.panelBorder

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            TextInput {
                id: search
                width: parent.width
                height: 42
                color: Theme.foreground
                font.family: Theme.regularFontFamily
                font.pixelSize: 22
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                onTextChanged: {
                    launcher.selected = 0
                    results.positionViewAtBeginning()
                }
                Keys.onEscapePressed: launcher.close()
                Keys.onDownPressed: {
                    launcher.selected = Math.min(launcher.selected + 1, Math.max(0, launcher.matches.length - 1))
                    results.positionViewAtIndex(launcher.selected, ListView.Contain)
                }
                Keys.onUpPressed: {
                    launcher.selected = Math.max(launcher.selected - 1, 0)
                    results.positionViewAtIndex(launcher.selected, ListView.Contain)
                }
                Keys.onReturnPressed: launcher.launch(launcher.selected)
                Keys.onEnterPressed: launcher.launch(launcher.selected)

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search applications..."
                    visible: !search.text
                    color: Theme.foreground
                    opacity: 0.5
                    font: search.font
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.foreground
                opacity: 0.25
            }

            ListView {
                id: results
                width: parent.width
                height: parent.height - search.height - 1 - parent.spacing * 2
                clip: true
                model: launcher.matches
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: results.width
                    height: 42
                    radius: 0
                    color: index === launcher.selected
                           ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.15)
                           : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 10

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: Theme.foreground
                            font.family: Theme.regularFontFamily
                            font.pixelSize: 20
                            elide: Text.ElideRight
                            width: search.width - 60
                        }
                    }

                    Rectangle {
                        visible: index < results.count - 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.foreground
                        opacity: 0.25
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: launcher.selected = index
                        onClicked: launcher.launch(index)
                        onWheel: wheel => wheel.accepted = false
                    }
                }

                Text {
                    visible: results.count === 0
                    text: "No applications found"
                    color: Theme.foreground
                    opacity: 0.6
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 20
                }
            }
        }
    }
}
