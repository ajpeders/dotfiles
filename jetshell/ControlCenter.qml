import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
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
    property string dnsPreset: ""
    readonly property var dnsPresets: [
        { id: "lan", name: "LAN", servers: "192.168.0.176" },
        { id: "router", name: "Router", servers: "DHCP" },
        { id: "cloudflare", name: "Cloudflare", servers: "1.1.1.1" }
    ]
    readonly property string dnsName: {
        const preset = dnsPresets.find(p => p.id === dnsPreset)
        return preset ? preset.name : dnsPreset === "custom" ? "Custom" : "…"
    }
    property var tailscale: null
    readonly property var tailscalePeers: tailscale && tailscale.Peer
        ? Object.values(tailscale.Peer).sort((a, b) => a.DNSName.localeCompare(b.DNSName)) : []
    readonly property bool tailscaleUp: !!tailscale && tailscale.BackendState === "Running"
    function peerName(peer) { return peer.DNSName.split(".")[0] || peer.HostName }
    function runTailscale(args) {
        if (tailscaleAction.running) return
        tailscaleAction.command = ["tailscale"].concat(args)
        tailscaleAction.running = true
    }
    function setDns(preset) {
        if (dnsSet.running) return
        dnsPreset = ""
        dnsSet.command = ["bash", Quickshell.shellPath("dns.sh"), "set", preset]
        dnsSet.running = true
    }
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
        id: slidersIcon
        anchors.centerIn: parent
        width: 22
        height: 18

        // Hand-drawn 11x9 pixel-art faders: three horizontal sliders with evenly
        // spaced rails and a small two-cell handle centered on each rail, at a
        // different position per row. Rendered on a 2px grid with square corners
        // so it stays crisp and matches the Tamzen pixel theme.
        readonly property var pixels: {
            const rows = [
                "..##.......",
                ".#########.",
                "..##.......",
                ".......##..",
                ".#########.",
                ".......##..",
                "....##.....",
                ".#########.",
                "....##....."
            ]
            const cells = []
            for (let y = 0; y < rows.length; ++y)
                for (let x = 0; x < rows[y].length; ++x)
                    if (rows[y][x] === "#") cells.push({ x: x, y: y })
            return cells
        }

        Repeater {
            model: slidersIcon.pixels

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
            else {
                dnsGet.running = true
                tailscaleStatus.running = true
            }
        }
        implicitWidth: controlCenter.currentTopic === "Audio" ? 560 : 360
        implicitHeight: Math.min(content.implicitHeight + 24, 600)
        color: Theme.background

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border.color: Theme.panelBorder
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
                        text: "DNS · " + (dnsSet.running ? "Switching…" : controlCenter.dnsName)
                        onClicked: controlCenter.currentTopic = "DNS"
                    }

                    ControlButton {
                        width: parent.width
                        height: 40
                        text: "Tailscale · " + (!controlCenter.tailscale ? "…"
                              : controlCenter.tailscaleUp ? "Connected" : controlCenter.tailscale.BackendState)
                        onClicked: controlCenter.currentTopic = "Tailscale"
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

                Repeater {
                    model: controlCenter.currentTopic === "DNS" ? controlCenter.dnsPresets : []
                    ControlButton {
                        required property var modelData
                        width: content.width
                        enabled: !dnsSet.running
                        text: (modelData.id === controlCenter.dnsPreset ? "✓ " : "") + modelData.name + " · " + modelData.servers
                        onClicked: controlCenter.setDns(modelData.id)
                    }
                }

                ControlButton {
                    width: parent.width
                    visible: controlCenter.currentTopic === "Tailscale"
                    enabled: !!controlCenter.tailscale && !tailscaleAction.running
                    text: tailscaleAction.running ? "Working…" : controlCenter.tailscaleUp ? "Disconnect" : "Connect"
                    onClicked: controlCenter.runTailscale([controlCenter.tailscaleUp ? "down" : "up"])
                }

                Text {
                    width: parent.width
                    visible: controlCenter.currentTopic === "Tailscale" && tailscaleAction.error !== ""
                    text: tailscaleAction.error
                    wrapMode: Text.WordWrap
                    color: Theme.foreground
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 14
                }

                Heading {
                    visible: controlCenter.currentTopic === "Tailscale" && controlCenter.tailscaleUp
                    text: "Exit node"
                }

                Repeater {
                    model: controlCenter.currentTopic === "Tailscale" && controlCenter.tailscaleUp
                           ? [null].concat(controlCenter.tailscalePeers.filter(peer => peer.ExitNodeOption)) : []
                    ControlButton {
                        required property var modelData
                        readonly property bool active: modelData ? modelData.ExitNode
                            : !controlCenter.tailscalePeers.some(peer => peer.ExitNode)
                        width: content.width
                        enabled: !tailscaleAction.running && (!modelData || modelData.Online)
                        text: (active ? "✓ " : "") + (modelData ? controlCenter.peerName(modelData) : "None")
                        onClicked: controlCenter.runTailscale(["set", "--exit-node="
                                                               + (modelData ? modelData.TailscaleIPs[0] : "")])
                    }
                }

                Heading {
                    visible: controlCenter.currentTopic === "Tailscale" && controlCenter.tailscaleUp
                    text: "Devices · click to copy IP"
                }

                Repeater {
                    model: controlCenter.currentTopic === "Tailscale" && controlCenter.tailscaleUp
                           ? [controlCenter.tailscale.Self].concat(controlCenter.tailscalePeers) : []
                    ControlButton {
                        required property var modelData
                        width: content.width
                        opacity: modelData.Online ? 1 : 0.5
                        text: (modelData.Online ? "● " : "○ ") + controlCenter.peerName(modelData)
                              + " · " + modelData.TailscaleIPs[0]
                        onClicked: Quickshell.execDetached(["wl-copy", modelData.TailscaleIPs[0]])
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
                        radius: 0
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
                                onClicked: {
                                    VolumeOsdState.suppress()
                                    audioColumn.node.audio.muted = !audioColumn.node.audio.muted
                                }
                            }

                            Slider {
                                width: parent.width
                                from: 0
                                to: 1
                                enabled: !!audioColumn.node && !!audioColumn.node.audio
                                value: enabled ? audioColumn.node.audio.volume : 0
                                onMoved: {
                                    VolumeOsdState.suppress()
                                    audioColumn.node.audio.volume = value
                                }
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
                                        VolumeOsdState.suppress()
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

    Process {
        id: dnsGet
        command: ["bash", Quickshell.shellPath("dns.sh"), "get"]
        stdout: StdioCollector {
            onStreamFinished: controlCenter.dnsPreset = text.trim()
        }
    }

    Process {
        id: tailscaleStatus
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { controlCenter.tailscale = JSON.parse(text) }
                catch (e) { controlCenter.tailscale = { BackendState: "Unavailable" } }
            }
        }
    }

    Process {
        id: tailscaleAction
        property string error: ""
        onStarted: error = ""
        stderr: StdioCollector {
            onStreamFinished: tailscaleAction.error = text.trim()
        }
        onExited: tailscaleStatus.running = true
    }

    Timer {
        interval: 5000
        repeat: true
        running: panel.visible && controlCenter.currentTopic === "Tailscale"
        onTriggered: tailscaleStatus.running = true
    }

    Process {
        id: dnsSet
        onExited: dnsGet.running = true
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
        font.bold: false
        wrapMode: Text.WordWrap
    }

    component ControlButton: Rectangle {
        property alias text: buttonLabel.text
        signal clicked()
        height: Math.max(32, buttonLabel.implicitHeight + 12)
        radius: 0
        border.width: 1
        border.color: Theme.panelBorder
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
