import Quickshell
import Quickshell._Window
import Quickshell.Services.Notifications
import QtQuick

FloatingWindow {
    id: quickSettings
    width: 300
    height: 420
    x: (Quickshell.screens[0].width - width) / 2
    y: 50
    visible: false
    focusable: true
    color: "transparent"

    NotificationServer { id: notifServer }

    property int wifiEnabled: 0
    property string wifiSsid: ""
    property int bluetoothEnabled: 0
    property string bluetoothDevice: ""
    property bool dndEnabled: false
    property bool nightLightEnabled: false
    property bool idleInhibitEnabled: false
    property bool gameModeEnabled: false

    Process { id: wifiProcess }
    Process { id: btProcess }
    Process { id: hyprsunsetProc }
    Process { id: hyprctlProc }
    Process { id: volProc }

    function refreshWifi() {
        wifiProcess.start("nmcli", ["-t", "-f", "ACTIVE,SSID", "dev", "wifi", "list"])
    }

    function refreshBluetooth() {
        btProcess.start("bluetoothctl", ["devices", "Connected"])
    }

    Timer {
        interval: 5000
        repeat: true
        onTriggered: { refreshWifi(); refreshBluetooth() }
    }

    OpacityAnimator {
        id: fadeIn
        target: quickSettings
        from: 0
        to: 1
        duration: Theme.animDuration
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panelBg

        Flickable {
            anchors.fill: parent
            contentWidth: parent.width
            contentHeight: col.height + Theme.padding * 2
            clip: true

            Column {
                id: col
                anchors.fill: parent
                padding: Theme.padding
                spacing: Theme.padding

                Grid {
                    columns: 2
                    spacing: 8

                    // Wi-Fi
                    qsToggle {
                        label: "Wi-Fi"; icon: "📶"
                        active: wifiEnabled === 2
                        sublabel: wifiSsid
                        onToggle: {
                            Process.start("nmcli", ["radio", "wifi", wifiEnabled === 2 ? "off" : "on"])
                            wifiEnabled = wifiEnabled === 2 ? 1 : 2
                        }
                    }

                    // Bluetooth
                    qsToggle {
                        label: "Bluetooth"; icon: "📙"
                        active: bluetoothEnabled === 2
                        sublabel: bluetoothDevice
                        onToggle: {
                            Process.start("bluetoothctl", ["power", bluetoothEnabled === 2 ? "off" : "on"])
                            bluetoothEnabled = bluetoothEnabled === 2 ? 1 : 2
                        }
                    }

                    // DND
                    qsToggle {
                        label: "DND"; icon: "🔕"
                        active: dndEnabled
                        onToggle: { dndEnabled = !dndEnabled; notifServer.dnd = dndEnabled }
                    }

                    // Night Light
                    qsToggle {
                        label: "Night Light"; icon: "🌙"
                        active: nightLightEnabled
                        onToggle: {
                            nightLightEnabled = !nightLightEnabled
                            if (nightLightEnabled) {
                                hyprsunsetProc.start("pkill", ["-f", "gammastep"])
                                hyprsunsetProc.start("hyprsunset", [])
                            } else {
                                hyprsunsetProc.start("pkill", ["-f", "hyprsunset"])
                            }
                        }
                    }

                    // Idle Inhibit
                    qsToggle {
                        label: "Idle Inhibit"; icon: "⏸"
                        active: idleInhibitEnabled
                        onToggle: idleInhibitEnabled = !idleInhibitEnabled
                    }

                    // Game Mode
                    qsToggle {
                        label: "Game Mode"; icon: "🎮"
                        active: gameModeEnabled
                        onToggle: {
                            gameModeEnabled = !gameModeEnabled
                            hyprctlProc.start("hyprctl", ["keyword", "animations:enabled", gameModeEnabled ? "false" : "true"])
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.borderColor }

                // Volume
                Row {
                    height: 30; spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "🔈"; font.pixelSize: 14 }
                    Rectangle {
                        width: 180; height: 6; anchors.verticalCenter: parent.verticalCenter; radius: 3; color: Theme.color0
                        Rectangle { width: 100; height: 6; radius: 3; color: Theme.accent }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "50%"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                }

                // Brightness
                Row {
                    height: 30; spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "☀️"; font.pixelSize: 14 }
                    Rectangle {
                        width: 180; height: 6; anchors.verticalCenter: parent.verticalCenter; radius: 3; color: Theme.color0
                        Rectangle { width: 140; height: 6; radius: 3; color: Theme.accent }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "70%"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                }

                // System Monitor
                Rectangle {
                    width: parent.width; height: 30; radius: Theme.radius; color: Theme.color0
                    Text { anchors.centerIn: parent; text: "📊 System Monitor"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                    MouseArea { anchors.fill: parent; onClicked: { quickSettings.visible = false; root.showSystemMonitor() } }
                }
            }
        }
    }

    function toggle() {
        visible = !visible
        if (visible) { refreshWifi(); refreshBluetooth(); fadeIn.start() }
    }
}

// Inline toggle button component
component QsToggle := Rectangle {
    property string label: ""
    property string icon: ""
    property string sublabel: ""
    property bool active: false
    property var onToggle: () => {}

    width: 130; height: 44; radius: Theme.radius
    color: active ? Theme.accent : Theme.color0

    Column {
        anchors.centerIn: parent; spacing: 2
        Row { spacing: 4; Text { text: parent.parent.icon; font.pixelSize: 12 } Text { text: label; color: active ? Theme.background : Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 } }
        Text { text: sublabel; color: active ? Theme.background : Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 3; visible: sublabel !== "" }
    }

    MouseArea { anchors.fill: parent; onClicked: onToggle() }
}
