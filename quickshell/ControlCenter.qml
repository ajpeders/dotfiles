import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Qt.labs.folderlistmodel

Item {
    id: controlCenter
    required property var selection
    property string currentTopic: ""
    readonly property alias popupWindow: panel
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var pairedDevices: adapter ? adapter.devices.values.filter(device => device.paired) : []
    readonly property var nearbyDevices: adapter ? adapter.devices.values.filter(device => !device.paired) : []
    property var scanningAdapter: null
    function startSearch() {
        if (!adapter || !adapter.enabled) return
        scanningAdapter = adapter
        adapter.discovering = true
        searchTimer.restart()
    }
    function stopSearch() {
        searchTimer.stop()
        if (scanningAdapter) scanningAdapter.discovering = false
        scanningAdapter = null
    }
    onCurrentTopicChanged: {
        if (currentTopic === "Bluetooth") startSearch()
        else stopSearch()
    }
    Component.onDestruction: stopSearch()
    readonly property var outputs: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && node.audio)
    readonly property var inputs: Pipewire.nodes.values.filter(node => !node.isSink && !node.isStream && node.audio)
    width: 30
    height: 30

    Item {
        id: gearIcon
        anchors.centerIn: parent
        width: 22
        height: 22

        // Hand-drawn 11x11 pixel-art gear. Rendered on a 2px grid with square
        // corners so it stays crisp and matches the Tamzen pixel theme.
        readonly property var pixels: {
            const rows = [
                "....###....",
                "....###....",
                "..#######..",
                ".#########.",
                "####...####",
                "####...####",
                "####...####",
                ".#########.",
                "..#######..",
                "....###....",
                "....###...."
            ]
            const cells = []
            for (let y = 0; y < rows.length; ++y)
                for (let x = 0; x < rows[y].length; ++x)
                    if (rows[y][x] === "#") cells.push({ x: x, y: y })
            return cells
        }

        Repeater {
            model: gearIcon.pixels

            Rectangle {
                required property var modelData
                x: modelData.x * 2
                y: modelData.y * 2
                width: 2
                height: 2
                color: Theme.foreground
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: controlCenter.selection.togglePanel("control-center")
    }

    PopupWindow {
        id: panel
        anchor.item: controlCenter
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.SlideX
        anchor.margins.bottom: 0
        visible: controlCenter.selection.activePanel === "control-center"
        onVisibleChanged: {
            if (!visible) controlCenter.currentTopic = ""
        }
        implicitWidth: controlCenter.currentTopic === "Audio" ? 560 : 360
        implicitHeight: Math.min(content.implicitHeight + 24, 600)
        color: Theme.background

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border.color: Theme.foreground
            border.width: 1
        }

        ScrollView {
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: availableWidth
            clip: true

            Column {
                id: content
                width: panel.width - 24
                spacing: 10

                Row {
                    width: parent.width
                    Heading {
                        width: content.width - 30
                        text: controlCenter.currentTopic || "Control center"
                    }
                    ControlButton {
                        width: 30
                        text: "×"
                        onClicked: controlCenter.selection.dismissPanels()
                    }
                }

                ControlButton {
                    width: parent.width
                    visible: controlCenter.currentTopic !== ""
                    text: "‹ Back"
                    onClicked: controlCenter.currentTopic = ""
                }

                Column {
                    visible: controlCenter.currentTopic === ""
                    width: parent.width
                    spacing: 10

                    ControlButton {
                        width: parent.width
                        height: 40
                        text: "Audio · " + (!controlCenter.sink || !controlCenter.sink.audio
                              ? "No output" : controlCenter.sink.audio.muted ? "Muted"
                              : Math.round(controlCenter.sink.audio.volume * 100) + "%")
                        onClicked: controlCenter.currentTopic = "Audio"
                    }

                    ControlButton {
                        width: parent.width
                        height: 40
                        text: "Bluetooth · " + (controlCenter.adapter
                              ? BluetoothAdapterState.toString(controlCenter.adapter.state) : "No adapter")
                        onClicked: controlCenter.currentTopic = "Bluetooth"
                    }

                    ControlButton {
                        width: parent.width
                        height: 40
                        text: "Theme · " + (Theme.mode === "black" ? "Dark"
                              : Theme.mode === "white" ? "Light" : "Wallpaper")
                        onClicked: Theme.cycle()
                    }

                    ControlButton {
                        width: parent.width
                        height: 40
                        text: "▣  Wallpaper"
                        onClicked: controlCenter.currentTopic = "Wallpaper"
                    }
                }

                Heading {
                    visible: controlCenter.currentTopic === "Wallpaper"
                    text: "Choose wallpaper"
                }

                FolderListModel {
                    id: wallpapers
                    folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
                    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
                    showDirs: false
                }

                Text {
                    visible: controlCenter.currentTopic === "Wallpaper" && wallpapers.count === 0
                    text: "No images in ~/Pictures/Wallpapers"
                    color: Theme.foreground
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 16
                }

                Repeater {
                    model: controlCenter.currentTopic === "Wallpaper" ? wallpapers : null
                    Rectangle {
                        id: wallpaperChoice
                        required property url fileUrl
                        required property string fileName
                        width: content.width
                        height: 68
                        radius: 4
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b,
                                       choiceMouse.containsMouse ? 0.18 : 0.08)

                        Image {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 88
                            height: 56
                            source: wallpaperChoice.fileUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 102
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: (Theme.wallpaper === wallpaperChoice.fileUrl.toString() ? "✓ " : "")
                                  + wallpaperChoice.fileName
                            elide: Text.ElideMiddle
                            color: Theme.foreground
                            font.family: Theme.regularFontFamily
                            font.pixelSize: 16
                        }
                        MouseArea {
                            id: choiceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.setWallpaper(wallpaperChoice.fileUrl)
                        }
                    }
                }

                Row {
                    width: parent.width
                    visible: controlCenter.currentTopic === "Audio"
                    spacing: 12

                    Repeater {
                        model: ["Input", "Output"]
                        Column {
                            id: audioColumn
                            required property string modelData
                            readonly property bool isInput: modelData === "Input"
                            readonly property var node: isInput ? controlCenter.source : controlCenter.sink
                            width: (parent.width - parent.spacing) / 2
                            spacing: 10

                            Heading { text: audioColumn.modelData }

                            ControlButton {
                                width: parent.width
                                enabled: !!audioColumn.node && !!audioColumn.node.audio
                                text: !enabled ? "No device" : audioColumn.node.audio.muted
                                      ? "Unmute" : "Mute · " + Math.round(audioColumn.node.audio.volume * 100) + "%"
                                onClicked: audioColumn.node.audio.muted = !audioColumn.node.audio.muted
                            }

                            Slider {
                                width: parent.width
                                from: 0
                                to: 1
                                enabled: !!audioColumn.node && !!audioColumn.node.audio
                                value: enabled ? audioColumn.node.audio.volume : 0
                                onMoved: audioColumn.node.audio.volume = value
                                palette.highlight: Theme.foreground
                            }

                            Repeater {
                                model: audioColumn.isInput ? controlCenter.inputs : controlCenter.outputs
                                ControlButton {
                                    required property var modelData
                                    width: audioColumn.width
                                    text: (modelData === audioColumn.node ? "✓ " : "")
                                          + (modelData.description || modelData.name)
                                    onClicked: {
                                        if (audioColumn.isInput) Pipewire.preferredDefaultAudioSource = modelData
                                        else Pipewire.preferredDefaultAudioSink = modelData
                                    }
                                }
                            }
                        }
                    }
                }

                Heading {
                    width: parent.width
                    visible: controlCenter.currentTopic === "Bluetooth"
                    text: "Bluetooth · " + (controlCenter.adapter
                          ? BluetoothAdapterState.toString(controlCenter.adapter.state) : "No adapter")
                }

                Heading {
                    visible: controlCenter.currentTopic === "Bluetooth"
                    text: "Paired devices"
                }

                Text {
                    visible: controlCenter.currentTopic === "Bluetooth" && controlCenter.pairedDevices.length === 0
                    text: "No paired devices"
                    color: Theme.foreground
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 16
                }

                Repeater {
                    model: controlCenter.currentTopic === "Bluetooth" ? controlCenter.pairedDevices : []
                    ControlButton {
                        required property var modelData
                        width: content.width
                        enabled: !!controlCenter.adapter && controlCenter.adapter.enabled
                                 && (modelData.state === BluetoothDeviceState.Connected
                                     || modelData.state === BluetoothDeviceState.Disconnected)
                        text: (modelData.connected ? "✓ " : "") + (modelData.name || modelData.address) + " · "
                              + BluetoothDeviceState.toString(modelData.state)
                        onClicked: modelData.connected = !modelData.connected
                    }
                }

                Rectangle {
                    visible: controlCenter.currentTopic === "Bluetooth"
                    width: parent.width
                    height: 1
                    color: Theme.foreground
                    opacity: 0.2
                }

                ControlButton {
                    width: parent.width
                    visible: controlCenter.currentTopic === "Bluetooth" && !!controlCenter.adapter
                    enabled: !!controlCenter.adapter
                             && controlCenter.adapter.state !== BluetoothAdapterState.Enabling
                             && controlCenter.adapter.state !== BluetoothAdapterState.Disabling
                    text: controlCenter.adapter && controlCenter.adapter.enabled ? "Turn off" : "Turn on"
                    onClicked: controlCenter.adapter.enabled = !controlCenter.adapter.enabled
                }

                ControlButton {
                    width: parent.width
                    visible: controlCenter.currentTopic === "Bluetooth"
                    enabled: !!controlCenter.adapter && controlCenter.adapter.enabled
                    text: controlCenter.adapter && controlCenter.adapter.discovering
                          ? "Searching… · Stop" : "Search for devices"
                    onClicked: {
                        if (controlCenter.scanningAdapter) controlCenter.stopSearch()
                        else controlCenter.startSearch()
                    }
                }

                ControlButton {
                    width: parent.width
                    visible: controlCenter.currentTopic === "Bluetooth"
                    enabled: !!controlCenter.adapter && controlCenter.adapter.enabled
                    text: "↻ Refresh"
                    onClicked: controlCenter.startSearch()
                }

                Rectangle {
                    visible: controlCenter.currentTopic === "Bluetooth"
                    width: parent.width
                    height: 1
                    color: Theme.foreground
                    opacity: 0.2
                }

                Heading {
                    visible: controlCenter.currentTopic === "Bluetooth"
                    text: "Nearby devices · " + controlCenter.nearbyDevices.length
                }

                Text {
                    width: parent.width
                    visible: controlCenter.currentTopic === "Bluetooth" && controlCenter.nearbyDevices.length === 0
                    text: controlCenter.adapter && controlCenter.adapter.discovering ? "Searching… Put your device in pairing mode."
                          : "Search to find devices in pairing mode."
                    wrapMode: Text.WordWrap
                    color: Theme.foreground
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 16
                }

                Repeater {
                    model: controlCenter.currentTopic === "Bluetooth" ? controlCenter.nearbyDevices : []
                    ControlButton {
                        required property var modelData
                        width: content.width
                        enabled: !!controlCenter.adapter && controlCenter.adapter.enabled && !modelData.pairing
                        text: (modelData.name || modelData.address) + (modelData.pairing ? " · Pairing…" : " · Pair")
                        onClicked: modelData.pair()
                    }
                }
            }
        }
    }

    PwObjectTracker {
        objects: controlCenter.outputs.concat(controlCenter.inputs)
    }

    Timer {
        id: searchTimer
        interval: 30000
        onTriggered: controlCenter.stopSearch()
    }

    component Heading: Text {
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 18
        font.bold: true
        wrapMode: Text.WordWrap
    }

    component ControlButton: Rectangle {
        property alias text: buttonLabel.text
        signal clicked()
        height: Math.max(32, buttonLabel.implicitHeight + 12)
        radius: 4
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
}
