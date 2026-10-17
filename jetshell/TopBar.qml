import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

PanelWindow {
    id: bar
    property string activePanel: ""
    readonly property bool showPlayer: AudioPlayer.player !== null
    readonly property var audioApps: {
        const groups = []
        for (const node of Pipewire.nodes.values.filter(node => node.isStream && node.isSink && node.audio)) {
            const props = node.properties || {}
            const name = (props["application.process.binary"] || props["application.name"]
                          || node.description || node.name).split("/").pop()
            let group = groups.find(group => group.name === name)
            if (!group) {
                group = { name: name, nodes: [] }
                groups.push(group)
            }
            group.nodes.push(node)
        }
        return groups
    }
    function dismissPanels() {
        activePanel = ""
        Notifications.centerOpen = false
        panelGrab.active = false
    }
    function togglePanel(name) {
        activePanel = activePanel === name ? "" : name
        Notifications.centerOpen = false
        panelGrab.active = activePanel !== ""
    }
    implicitHeight: 30
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
    }
    exclusiveZone: 30

    HyprlandFocusGrab {
        id: panelGrab
        windows: [bar, trayPopup, aiUsagePanel, audioPopup, playerUi.popupWindow,
                  cpuPopup, gpuPopup, calendarPopup, controls.popupWindow]
        onCleared: bar.dismissPanels()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background

        MouseArea {
            anchors.fill: parent
            onClicked: bar.dismissPanels()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // === LEFT: Workspaces ===
        Repeater {
            model: Hyprland.workspaces

            Rectangle {
                required property var modelData
                property bool onScreen: modelData.id > 0 && modelData.monitor
                                        && modelData.monitor.name === bar.screen.name
                visible: onScreen
                Layout.preferredWidth: onScreen ? 28 : 0
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 4
                radius: 0
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: modelData.id
                    color: modelData.active ? Theme.foreground : Theme.mode === "white" ? "#666666"
                           : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.6)
                    font.family: modelData.active ? Theme.fontFamily : Theme.regularFontFamily
                    font.pixelSize: 20
                    font.bold: modelData.active
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        bar.dismissPanels()
                        modelData.activate()
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 16
            Layout.leftMargin: 8
            color: Theme.foreground
            opacity: 0.2
        }

        Item {
            id: volumeSlider
            Layout.preferredWidth: volumeBars.width + 8 + volumePercent.implicitWidth
            Layout.preferredHeight: 26
            Layout.leftMargin: 8
            Layout.alignment: Qt.AlignVCenter
            readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

            function setVolume(x) {
                if (!audio) return
                VolumeOsdState.suppress()
                audio.volume = Math.max(0, Math.min(1, x / volumeBars.width))
            }

            Row {
                id: volumeBars
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 22
                spacing: 2

                Repeater {
                    model: 12
                    Item {
                        required property int index
                        width: 5
                        height: 22

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 6 + Math.round(index * 16 / 11)
                            color: Theme.foreground
                            opacity: volumeSlider.audio && !volumeSlider.audio.muted
                                     && volumeSlider.audio.volume >= (index + 1) / 12 ? 1 : 0.2
                        }
                    }
                }
            }

            Text {
                id: volumePercent
                anchors.left: volumeBars.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: volumeSlider.audio ? Math.round(volumeSlider.audio.volume * 100) + "%" : "--%"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 20
            }

            MouseArea {
                anchors.fill: volumePercent
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.togglePanel("audio")
            }

            MouseArea {
                anchors.fill: volumeBars
                enabled: !!volumeSlider.audio
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => volumeSlider.setVolume(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed) volumeSlider.setVolume(mouse.x)
                }
            }

            PopupWindow {
                id: audioPopup
                anchor.item: volumeSlider
                anchor.edges: Edges.Bottom | Edges.Left
                anchor.gravity: Edges.Bottom | Edges.Right
                anchor.adjustment: PopupAdjustment.SlideX
                visible: bar.activePanel === "audio"
                implicitWidth: Math.min(460, bar.screen.width - 16)
                implicitHeight: audioContent.implicitHeight + 24
                color: Theme.background

                Rectangle {
                    anchors.fill: parent
                    color: Theme.background
                    border.color: Theme.panelBorder
                    border.width: 1
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 12

                    Column {
                        id: audioContent
                        width: audioPopup.width - 24
                        spacing: 12

                        Text {
                            text: "Audio"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                        }

                        Text {
                            text: "Applications"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                        }

                        Text {
                            visible: bar.audioApps.length === 0
                            text: "No apps playing audio"
                            color: Theme.foreground
                            font.family: Theme.regularFontFamily
                            font.pixelSize: 16
                        }

                        Repeater {
                            model: bar.audioApps

                            Column {
                                id: appMixer
                                required property var modelData
                                width: audioContent.width
                                spacing: 4
                                readonly property var nodes: modelData.nodes
                                readonly property bool muted: nodes.every(node => node.audio.muted)

                                Text {
                                    width: parent.width
                                    text: appMixer.modelData.name
                                    elide: Text.ElideRight
                                    color: Theme.foreground
                                    font.family: Theme.regularFontFamily
                                    font.pixelSize: 16
                                }

                                Row {
                                    width: parent.width
                                    spacing: 8

                                    AudioButton {
                                        width: 70
                                        text: appMixer.muted ? "Unmute" : "Mute"
                                        onClicked: {
                                            VolumeOsdState.suppress()
                                            const mute = !appMixer.muted
                                            for (const node of appMixer.nodes) node.audio.muted = mute
                                        }
                                    }

                                    Slider {
                                        width: parent.width - 130
                                        anchors.verticalCenter: parent.verticalCenter
                                        from: 0
                                        to: 1
                                        value: appMixer.nodes[0].audio.volume
                                        onMoved: {
                                            for (const node of appMixer.nodes) node.audio.volume = value
                                        }
                                        palette.highlight: Theme.foreground
                                    }

                                    Text {
                                        width: 44
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(appMixer.nodes[0].audio.volume * 100) + "%"
                                        color: Theme.foreground
                                        font.family: Theme.regularFontFamily
                                        font.pixelSize: 16
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 12

                            Repeater {
                                model: ["Output", "Input"]
                                Column {
                                    id: audioColumn
                                    required property string modelData
                                    readonly property bool isInput: modelData === "Input"
                                    readonly property var node: isInput ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
                                    width: (audioContent.width - 12) / 2
                                    spacing: 10

                                    Text {
                                        text: audioColumn.modelData
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 18
                                    }

                                    AudioButton {
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
                                        model: audioColumn.isInput
                                               ? Pipewire.nodes.values.filter(node => !node.isSink && !node.isStream && node.audio)
                                               : Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && node.audio)
                                        AudioButton {
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

                    }
                }
            }
        }

        AudioPlayerUI {
            id: playerUi
            visible: bar.showPlayer
            Layout.preferredWidth: 500
            Layout.fillHeight: true
            selection: bar
        }

        Item { Layout.fillWidth: true }

        // === RIGHT: Status row ===
        Row {
            id: statusRow
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 8
            Layout.rightMargin: 12
            spacing: 12

            Item {
                id: tray
                readonly property bool expanded: bar.activePanel === "tray"
                function itemName(item) {
                    return item.tooltipTitle || item.title || item.id
                }
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 30

                Text {
                    text: "<"
                    rotation: tray.expanded ? 90 : -90
                    anchors.centerIn: parent
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.togglePanel("tray")
                }

                PopupWindow {
                    id: trayPopup
                    anchor.item: tray
                    anchor.edges: Edges.Bottom | Edges.Left
                    anchor.gravity: Edges.Bottom | Edges.Right
                    anchor.adjustment: PopupAdjustment.FlipX | PopupAdjustment.SlideX
                    visible: tray.expanded
                    implicitWidth: Math.min(bar.screen.width - 16, Math.max(120,
                        ...SystemTray.items.values.map(item => trayFontMetrics.advanceWidth(tray.itemName(item)) + 56)))
                    implicitHeight: Math.min(trayContent.implicitHeight + 16, 400)
                    color: Theme.background

                    FontMetrics {
                        id: trayFontMetrics
                        font.family: Theme.regularFontFamily
                        font.pixelSize: 16
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.background
                        border.color: Theme.panelBorder
                        border.width: 1
                    }

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 8
                        contentHeight: trayContent.implicitHeight
                        clip: true

                        Column {
                            id: trayContent
                            width: parent.width
                            spacing: 4

                            Text {
                                visible: SystemTray.items.values.length === 0
                                text: "No tray items"
                                color: Theme.foreground
                                font.family: Theme.regularFontFamily
                                font.pixelSize: 16
                            }

                            Repeater {
                                model: SystemTray.items

                                Rectangle {
                                    id: trayIcon
                                    required property var modelData
                                    width: trayContent.width
                                    height: Math.max(32, trayLabel.implicitHeight + 12)
                                    radius: 4
                                    color: trayMouse.containsMouse
                                           ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
                                           : "transparent"

                                    Image {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 20
                                        height: 20
                                        source: trayIcon.modelData.id.startsWith("discord_status_icon_")
                                                ? Quickshell.iconPath("discord") : trayIcon.modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Text {
                                        id: trayLabel
                                        anchors.left: parent.left
                                        anchors.leftMargin: 34
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tray.itemName(trayIcon.modelData)
                                        wrapMode: Text.Wrap
                                        color: Theme.foreground
                                        font.family: Theme.regularFontFamily
                                        font.pixelSize: 16
                                    }

                                    MouseArea {
                                        id: trayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            bar.dismissPanels()
                                            if (mouse.button === Qt.MiddleButton) trayIcon.modelData.secondaryActivate()
                                            else if (mouse.button === Qt.RightButton || trayIcon.modelData.onlyMenu)
                                                trayIcon.modelData.display(bar, tray.mapToItem(null, 0, tray.height).x,
                                                                           tray.height)
                                            else trayIcon.modelData.activate()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: aiUsageRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                readonly property bool anyShown: AIUsage.providerList.some(entry => AIUsage.shown(entry.id))
                                                  || AIUsage.shown("deepseek")

                Repeater {
                    model: AIUsage.providerList

                    AiUsageIndicator {
                        required property var modelData
                        providerId: modelData.id
                        selection: bar
                    }
                }

                DeepseekIndicator {
                    id: deepseekUsage
                    selection: bar
                }

                // Keeps the panel reachable when every provider is toggled off,
                // since the row is otherwise empty and nothing would be clickable.
                Item {
                    id: aiUsageButton
                    visible: !aiUsageRow.anyShown
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    // Hand-drawn 9x9 pixel-art sparkle on a 2px grid, matching
                    // the faders icon in ControlCenter.
                    readonly property var pixels: {
                        const rows = [
                            "....#....",
                            "...###...",
                            "..#####..",
                            ".#######.",
                            "#########",
                            ".#######.",
                            "..#####..",
                            "...###...",
                            "....#...."
                        ]
                        const cells = []
                        for (let y = 0; y < rows.length; ++y)
                            for (let x = 0; x < rows[y].length; ++x)
                                if (rows[y][x] === "#") cells.push({ x: x, y: y })
                        return cells
                    }

                    Repeater {
                        model: aiUsageButton.pixels

                        Rectangle {
                            required property var modelData
                            x: modelData.x * 2
                            y: modelData.y * 2
                            width: 2
                            height: 2
                            color: Theme.foreground
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.togglePanel("ai-usage")
                    }
                }

                PopupWindow {
                    id: aiUsagePanel
                    anchor.item: aiUsageRow
                    anchor.edges: Edges.Bottom | Edges.Left
                    anchor.gravity: Edges.Bottom | Edges.Right
                    anchor.adjustment: PopupAdjustment.FlipX | PopupAdjustment.SlideX
                    anchor.margins.bottom: 0
                    visible: bar.activePanel === "ai-usage"
                    // The quota probe runs on a slow timer; re-read the balance
                    // on open so the number is current when it is read.
                    onVisibleChanged: if (visible) AIUsage.refreshDeepseek()
                    implicitWidth: Math.min(400, bar.screen.width - 16)
                    implicitHeight: Math.min(aiUsageContent.implicitHeight + 32, bar.screen.height - 40)
                    color: Theme.background

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.background
                        border.color: Theme.mode === "white" ? Theme.panelBorder : "#000000"
                        border.width: 1
                    }

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 16
                        contentHeight: aiUsageContent.implicitHeight
                        clip: true

                        Column {
                            id: aiUsageContent
                            width: aiUsagePanel.width - 32
                            spacing: 18

                            Text {
                                text: "AI usage"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 20
                            }

                            Repeater {
                                model: AIUsage.providerList

                                Column {
                                    id: providerSection
                                    required property var modelData
                                    width: aiUsageContent.width
                                    spacing: 10

                                    Rectangle {
                                        visible: !AIUsage.isFirst(providerSection.modelData.id)
                                        width: parent.width
                                        height: 1
                                        color: Theme.foreground
                                        opacity: 0.4
                                    }

                                    Item {
                                        width: parent.width
                                        height: Math.max(providerLabel.implicitHeight, providerToggle.implicitHeight)

                                        Text {
                                            id: providerLabel
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: providerSection.modelData.display_name
                                                  || providerSection.modelData.id
                                            color: Theme.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 20
                                        }

                                        UsageToggle {
                                            id: providerToggle
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            checked: AIUsage.shown(providerSection.modelData.id)
                                            onToggled: AIUsage.toggleShown(providerSection.modelData.id)
                                        }
                                    }

                                    Repeater {
                                        model: providerSection.modelData.metrics

                                        Column {
                                            id: usageWindow
                                            required property var modelData
                                            width: providerSection.width
                                            spacing: 2
                                            Row {
                                                width: usageWindow.width
                                                Text {
                                                    width: 140
                                                    text: usageWindow.modelData.label
                                                    color: Theme.foreground
                                                    font.family: Theme.regularFontFamily
                                                    font.pixelSize: 18
                                                }
                                                Text {
                                                    text: usageWindow.modelData.value
                                                    color: Theme.foreground
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 20
                                                }
                                            }
                                            Text {
                                                width: usageWindow.width
                                                wrapMode: Text.WordWrap
                                                text: usageWindow.modelData.detail || "Usage unavailable"
                                                color: Theme.foreground
                                                font.family: Theme.regularFontFamily
                                                font.pixelSize: 16
                                                opacity: 0.85
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                visible: AIUsage.deepseekBalance !== ""
                                width: aiUsageContent.width
                                spacing: 10

                                Rectangle {
                                    visible: AIUsage.providerList.length > 0
                                    width: parent.width
                                    height: 1
                                    color: Theme.foreground
                                    opacity: 0.4
                                }

                                Item {
                                    width: parent.width
                                    height: Math.max(deepseekLabel.implicitHeight, deepseekToggle.implicitHeight)

                                    Text {
                                        id: deepseekLabel
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "DeepSeek"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 20
                                    }

                                    UsageToggle {
                                        id: deepseekToggle
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: AIUsage.shown("deepseek")
                                        onToggled: AIUsage.toggleShown("deepseek")
                                    }
                                }
                                Row {
                                    Text {
                                        width: 140
                                        text: "Balance"
                                        color: Theme.foreground
                                        font.family: Theme.regularFontFamily
                                        font.pixelSize: 18
                                    }
                                    Text {
                                        text: AIUsage.deepseekBalance
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 20
                                    }
                                }
                                Text {
                                    text: "DeepSeek account balance."
                                    color: Theme.foreground
                                    font.family: Theme.regularFontFamily
                                    font.pixelSize: 16
                                    opacity: 0.85
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                opacity: 0.35
            }

            Text {
                text: "RAM " + Metrics.memoryUsed
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.bold: false
            }

            Rectangle {
                width: 1
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                opacity: 0.35
            }

            Item {
                id: cpuArea
                width: cpuLabel.implicitWidth
                height: 30
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: cpuLabel
                    anchors.centerIn: parent
                    text: "CPU " + Metrics.cpu
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    font.bold: false
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.togglePanel("cpu")
                }

                PopupWindow {
                    id: cpuPopup
                    anchor.item: cpuArea
                    anchor.edges: Edges.Bottom | Edges.Left
                    anchor.gravity: Edges.Bottom | Edges.Right
                    anchor.adjustment: PopupAdjustment.SlideX
                    anchor.margins.bottom: 0
                    visible: bar.activePanel === "cpu"
                    implicitWidth: Math.min(310, Math.max(220, bar.width - statusRow.x - cpuArea.x - 12))
                    implicitHeight: Math.min(360, 92 + Math.ceil(Metrics.cpuCores.length / 2) * 24)
                    color: Theme.background

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.background
                        border.color: Theme.mode === "white" ? Theme.panelBorder : "#000000"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Text {
                                text: "CPU usage  " + Metrics.cpu
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.bold: false
                            }
                            Text {
                                text: "Load (1/5/15m)  " + Metrics.loadAverage
                                color: Theme.foreground
                                font.family: Theme.regularFontFamily
                                font.pixelSize: 16
                            }
                            Flickable {
                                width: parent.width
                                height: parent.height - y
                                contentHeight: coreList.implicitHeight
                                clip: true

                                Grid {
                                    id: coreList
                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 8
                                    Repeater {
                                        model: Metrics.cpuCores
                                        Text {
                                            required property var modelData
                                            width: (coreList.width - coreList.columnSpacing) / 2
                                            height: 24
                                            text: modelData.label + "  " + modelData.usage
                                            color: Theme.foreground
                                            font.family: Theme.regularFontFamily
                                            font.pixelSize: 16
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                opacity: 0.35
            }

            Item {
                id: gpuArea
                width: gpuRow.implicitWidth
                height: 30
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: gpuRow
                    anchors.centerIn: parent
                    spacing: 10
                    Repeater {
                        model: Metrics.gpuCards
                        Row {
                            required property var modelData
                            spacing: 5

                            Text {
                                text: modelData.label
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.bold: false
                            }

                            Rectangle {
                                width: 24
                                height: 5
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.2)
                                border.color: Theme.foreground
                                border.width: 1

                                Rectangle {
                                    x: 1
                                    y: 1
                                    width: (parent.width - 2) * Math.max(0, Math.min(1, modelData.used / modelData.total || 0))
                                    height: parent.height - 2
                                    color: Theme.foreground
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.togglePanel("gpu")
                }

                PopupWindow {
                    id: gpuPopup
                    anchor.item: gpuArea
                    anchor.edges: Edges.Bottom | Edges.Left
                    anchor.gravity: Edges.Bottom | Edges.Right
                    anchor.adjustment: PopupAdjustment.SlideX
                    anchor.margins.bottom: 0
                    visible: bar.activePanel === "gpu" && Metrics.gpuCards.length > 0
                    implicitWidth: Math.min(300, Math.max(200, bar.width - statusRow.x - gpuArea.x - 12))
                    implicitHeight: detailsColumn.implicitHeight + 16
                    color: Theme.background

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.background
                        border.color: Theme.mode === "white" ? Theme.panelBorder : "#000000"
                        border.width: 1

                        Column {
                            id: detailsColumn
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            Repeater {
                                model: Metrics.gpuCards
                                Column {
                                    required property var modelData
                                    spacing: 0

                                    Text {
                                        width: gpuPopup.width - 16
                                        wrapMode: Text.WordWrap
                                        text: modelData.label + "  " + modelData.name
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 18
                                        font.bold: false
                                    }
                                    Text {
                                        width: gpuPopup.width - 16
                                        wrapMode: Text.WordWrap
                                        text: modelData.total > 0
                                              ? modelData.used.toFixed(1) + " / " + modelData.total.toFixed(1) + " GB VRAM used ("
                                                + Math.round(100 * modelData.used / modelData.total) + "%)"
                                              : "VRAM unavailable"
                                        color: Theme.foreground
                                        font.family: Theme.regularFontFamily
                                        font.pixelSize: 16
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
                width: 1
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                opacity: 0.35
            }

            Text {
                visible: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
                text: "BAT " + Math.round(UPower.displayDevice.percentage) + "%"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.bold: false
            }

            Rectangle {
                width: 1
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                opacity: 0.35
            }

            ControlCenter {
                id: controls
                anchors.verticalCenter: parent.verticalCenter
                selection: bar
            }
        }
    }

    // Center on the bar, regardless of the width of the side widgets.
    Item {
        id: clockArea
        anchors.centerIn: parent
        width: clockLabel.implicitWidth
        height: 30

        Text {
            id: clockLabel
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "ddd MMM d  h:mm:ss AP")
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.bold: false
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.togglePanel("calendar")
        }

        PopupWindow {
            id: calendarPopup
            // First day of the month being shown; reset to today on open.
            property date viewMonth: new Date()
            readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
            readonly property int offset: (new Date(viewMonth.getFullYear(), viewMonth.getMonth(), 1).getDay()
                                           - firstDay + 7) % 7
            function shiftMonth(delta) {
                viewMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + delta, 1)
            }
            anchor.item: clockArea
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.adjustment: PopupAdjustment.SlideX
            visible: bar.activePanel === "calendar"
            onVisibleChanged: if (visible) viewMonth = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
            implicitWidth: 7 * 36 + 20
            implicitHeight: calendarColumn.implicitHeight + 20
            color: Theme.background

            Rectangle {
                anchors.fill: parent
                color: Theme.background
                border.color: Theme.mode === "white" ? Theme.panelBorder : "#000000"
                border.width: 1

                Column {
                    id: calendarColumn
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 26

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "<"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarPopup.shiftMonth(-1)
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: Qt.formatDate(calendarPopup.viewMonth, "MMMM yyyy")
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarPopup.viewMonth = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: ">"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarPopup.shiftMonth(1)
                            }
                        }
                    }

                    Grid {
                        columns: 7

                        Repeater {
                            model: 7
                            Text {
                                required property int index
                                width: 36
                                height: 24
                                horizontalAlignment: Text.AlignHCenter
                                text: Qt.locale().dayName((calendarPopup.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2)
                                color: Theme.foreground
                                opacity: 0.6
                                font.family: Theme.regularFontFamily
                                font.pixelSize: 16
                            }
                        }

                        Repeater {
                            model: 42
                            Rectangle {
                                required property int index
                                readonly property date day: new Date(calendarPopup.viewMonth.getFullYear(),
                                                                     calendarPopup.viewMonth.getMonth(),
                                                                     index - calendarPopup.offset + 1)
                                readonly property bool inMonth: day.getMonth() === calendarPopup.viewMonth.getMonth()
                                readonly property bool isToday: day.toDateString() === clock.date.toDateString()
                                width: 36
                                height: 26
                                color: isToday ? Theme.foreground : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.day.getDate()
                                    color: parent.isToday ? Theme.background : Theme.foreground
                                    opacity: parent.inMonth ? 1 : 0.35
                                    font.family: parent.isToday ? Theme.fontFamily : Theme.regularFontFamily
                                    font.pixelSize: 16
                                    font.bold: parent.isToday
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node.audio)
    }

    // Small pixel switch used by the AI usage panel to show/hide a provider's
    // indicator in the bar.
    component UsageToggle: Item {
        id: toggle
        property bool checked: true
        signal toggled()
        implicitWidth: 34
        implicitHeight: 18

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b,
                           toggleMouse.containsMouse ? 0.18 : 0.08)
            border.width: 1
            border.color: Theme.panelBorder

            Rectangle {
                width: 14
                height: parent.height - 4
                anchors.verticalCenter: parent.verticalCenter
                x: toggle.checked ? parent.width - width - 2 : 2
                color: toggle.checked ? Theme.foreground
                                      : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.35)
                Behavior on x { NumberAnimation { duration: 120 } }
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }

}
