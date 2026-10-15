import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

PanelWindow {
    id: bar
    property string activePanel: ""
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
        windows: [bar, claudeUsage.popupWindow, codexUsage.popupWindow,
                  deepseekUsage.popupWindow, trayPopup, cpuPopup, gpuPopup, controls.popupWindow]
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
                radius: 5
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
            visible: AudioPlayer.title.length > 0
            Layout.preferredWidth: 1
            Layout.preferredHeight: 16
            Layout.leftMargin: 8
            color: Theme.foreground
            opacity: 0.2
        }

        AudioPlayerUI {
            visible: AudioPlayer.title.length > 0
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
                        border.color: Theme.foreground
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
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                AiUsageIndicator {
                    id: claudeUsage
                    providerId: "anthropic"
                    providerName: "Claude"
                    iconName: "claude"
                    selection: bar
                }
                AiUsageIndicator {
                    id: codexUsage
                    providerId: "openai"
                    providerName: "Codex"
                    iconName: "codex"
                    selection: bar
                }
                DeepseekIndicator {
                    id: deepseekUsage
                    selection: bar
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
                font.bold: true
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
                    font.bold: true
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
                        border.color: "#000000"
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
                                font.bold: true
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
                                font.bold: true
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
                        border.color: "#000000"
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
                                        font.bold: true
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
                width: 1
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                opacity: 0.35
            }

            Text {
                text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                      ? (Pipewire.defaultAudioSink.audio.muted ? "Muted" : "Vol " + Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%")
                      : "No audio"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.bold: true
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
                font.bold: true
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
    Text {
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd MMM d  h:mm:ss AP")
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 20
        font.bold: true
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
}
