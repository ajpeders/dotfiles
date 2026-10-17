import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Clipboard history picker. cliphist records in the background
// (systemd/user/cliphist.service, `wl-paste --watch cliphist store`); this panel
// only reads the list, so it stays cheap while closed.
PanelWindow {
    id: panel
    visible: false
    color: "transparent"
    implicitWidth: 540
    implicitHeight: 470
    anchors { top: true }
    margins.top: Math.max(40, Math.round((screen.height - implicitHeight) / 2))
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    property int selected: 0
    property var entries: []

    // `cliphist list` prints "<id>\t<text>" per entry, newest first. Binary
    // entries (images) come through as a "[[: binary data ... ]]" preview and
    // still copy fine, since copying goes back through `cliphist decode`.
    readonly property var matches: {
        const query = search.text.trim().toLowerCase()
        if (!query) return entries
        return entries.filter(entry => entry.text.toLowerCase().includes(query))
    }

    function preview(text) {
        const single = text.replace(/\s+/g, " ").trim()
        return single.length ? single : "(empty)"
    }

    function open() {
        const monitor = Hyprland.focusedMonitor
        const target = Quickshell.screens.find(s => monitor && s.name === monitor.name)
        if (target) screen = target
        search.text = ""
        selected = 0
        visible = true
        grab.active = true
        history.running = true
        Qt.callLater(() => search.forceActiveFocus())
    }

    function close() {
        grab.active = false
        visible = false
    }

    function choose(index) {
        if (index < 0 || index >= matches.length) return
        const entry = matches[index]
        close()
        // decode puts the original entry (text or image) back on the clipboard.
        copy.command = ["sh", "-c", "cliphist decode " + entry.id + " | wl-copy"]
        copy.running = true
    }

    function forget(index) {
        if (index < 0 || index >= matches.length) return
        remove.command = ["cliphist", "delete", matches[index].id]
        remove.running = true
    }

    HyprlandFocusGrab {
        id: grab
        windows: [panel]
        onCleared: panel.close()
    }

    Process {
        id: history
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.entries = text.split("\n").filter(line => line.length > 0).map(line => {
                    const tab = line.indexOf("\t")
                    return tab < 0 ? { id: line, text: "" }
                                   : { id: line.slice(0, tab), text: line.slice(tab + 1) }
                })
                panel.selected = 0
            }
        }
    }

    Process { id: copy }

    Process {
        id: remove
        onExited: history.running = true // ids shift after a delete; reload the list
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
                    panel.selected = 0
                    results.positionViewAtBeginning()
                }
                Keys.onEscapePressed: panel.close()
                Keys.onDownPressed: {
                    panel.selected = Math.min(panel.selected + 1, Math.max(0, panel.matches.length - 1))
                    results.positionViewAtIndex(panel.selected, ListView.Contain)
                }
                Keys.onUpPressed: {
                    panel.selected = Math.max(panel.selected - 1, 0)
                    results.positionViewAtIndex(panel.selected, ListView.Contain)
                }
                Keys.onReturnPressed: panel.choose(panel.selected)
                Keys.onEnterPressed: panel.choose(panel.selected)
                // Shift+Delete drops the entry; plain Delete still edits the query.
                Keys.onDeletePressed: event => {
                    if (!event.modifiers) return
                    panel.forget(panel.selected)
                    event.accepted = true
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Search clipboard..."
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
                model: panel.matches
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: results.width
                    height: 42
                    radius: 0
                    color: index === panel.selected
                           ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.15)
                           : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: panel.preview(modelData.text)
                        color: Theme.foreground
                        font.family: Theme.regularFontFamily
                        font.pixelSize: 20
                        elide: Text.ElideRight
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
                        onEntered: panel.selected = index
                        onClicked: panel.choose(index)
                        onWheel: wheel => wheel.accepted = false
                    }
                }

                Text {
                    visible: results.count === 0
                    text: panel.entries.length === 0 ? "Clipboard is empty" : "No matches"
                    color: Theme.foreground
                    opacity: 0.6
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 20
                }
            }
        }
    }
}
