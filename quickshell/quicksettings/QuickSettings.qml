import QtQuick
import Quickshell.Panels

PopupWindow {
    id: quickSettings
    width: 300
    height: contentColumn.height + Theme.padding * 2
    anchor: PopupWindow.TopEdge
    margin: 4
    closePolicy: PopupWindow.ClickOutside | PopupWindow.Escape

    property int wifiEnabled: false
    property string wifiSsid: ""
    property int bluetoothEnabled: false
    property string bluetoothDevice: ""
    property bool dndEnabled: false
    property bool nightLightEnabled: false
    property bool idleInhibitEnabled: false
    property bool gameModeEnabled: false

    Process {
        id: wifiProcess
        onFinished: (code) => {
            if (code !== 0) return
            const out = wifiProcess.read()
            wifiEnabled = out.includes("connected")
            wifiSsid = extractSsid(out)
        }
    }

    Process {
        id: btProcess
        onFinished: (code) => {
            if (code !== 0) return
            const out = btProcess.read()
            bluetoothEnabled = out.includes("Connected")
            bluetoothDevice = extractBtDevice(out)
        }
    }

    function extractSsid(output) { return "" }  // implement
    function extractBtDevice(output) { return "" }  // implement

    function refreshWifi() {
        wifiProcess.start("nmcli", ["-t", "-f", "ACTIVE,SSID", "dev", "wifi", "list"])
    }

    function refreshBluetooth() {
        btProcess.start("bluetoothctl", ["devices", "Connected"])
    }

    Timer {
        interval: 5000
        repeat: true
        onTriggered: {
            refreshWifi()
            refreshBluetooth()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panelBg

        Column {
            id: contentColumn
            anchors.fill: parent
            padding: Theme.padding
            spacing: Theme.padding

            // Toggle grid
            Grid {
                columns: 2
                spacing: 8

                ToggleButton {
                    label: "Wi-Fi"
                    icon: "📶"
                    active: wifiEnabled
                    sublabel: wifiSsid
                    onToggle: {
                        wifiProcess.start("nmcli", ["radio", "wifi", wifiEnabled ? "off" : "on"])
                        wifiEnabled = !wifiEnabled
                    }
                }

                ToggleButton {
                    label: "Bluetooth"
                    icon: "📙"
                    active: bluetoothEnabled
                    sublabel: bluetoothDevice
                    onToggle: {
                        btProcess.start("bluetoothctl", ["power", bluetoothEnabled ? "off" : "on"])
                        bluetoothEnabled = !bluetoothEnabled
                    }
                }

                ToggleButton {
                    label: "DND"
                    icon: "🔕"
                    active: dndEnabled
                    onToggle: {
                        dndEnabled = !dndEnabled
                        notifServer.dnd = dndEnabled
                    }
                }

                ToggleButton {
                    label: "Night Light"
                    icon: "🌙"
                    active: nightLightEnabled
                    onToggle: {
                        nightLightEnabled = !nightLightEnabled
                        hyprsunsetProcess.start(nightLightEnabled ? "" : "-k")
                    }
                }

                ToggleButton {
                    label: "Idle Inhibit"
                    icon: "⏸"
                    active: idleInhibitEnabled
                    onToggle: idleInhibitEnabled = !idleInhibitEnabled
                }

                ToggleButton {
                    label: "Game Mode"
                    icon: "🎮"
                    active: gameModeEnabled
                    onToggle: {
                        gameModeEnabled = !gameModeEnabled
                        // Disable/enable Hyprland animations
                        hyprctlProcess.start("hyprctl", ["keyword", "animations:enabled", gameModeEnabled ? "false" : "true"])
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.borderColor
            }

            // Volume slider
            Row {
                height: 30
                spacing: 8

                Text { anchors.verticalCenter: parent.verticalCenter; text: "🔈"; font.pixelSize: 14 }
                Rectangle {
                    width: 180
                    height: 6
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 3
                    color: Theme.color0
                    Rectangle { width: 50; height: 6; radius: 3; color: Theme.accent }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "50%"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
            }

            // Brightness slider
            Row {
                height: 30
                spacing: 8

                Text { anchors.verticalCenter: parent.verticalCenter; text: "☀️"; font.pixelSize: 14 }
                Rectangle {
                    width: 180
                    height: 6
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 3
                    color: Theme.color0
                    Rectangle { width: 70; height: 6; radius: 3; color: Theme.accent }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "70%"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
            }

            // System Monitor button
            Rectangle {
                width: parent.width
                height: 30
                radius: Theme.radius
                color: Theme.color0

                Text { anchors.centerIn: parent; text: "📊 System Monitor"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }

                MouseArea {
                    anchors.fill: parent
                    onClicked: app.showSystemMonitor()
                }
            }
        }
    }

    Process { id: hyprsunsetProcess }
    Process { id: hyprctlProcess }
    NotificationServer { id: notifServer }

    Component.onCompleted: {
        refreshWifi()
        refreshBluetooth()
    }
}

Component {
    id: ToggleButton

    Rectangle {
        property string label: ""
        property string icon: ""
        property string sublabel: ""
        property bool active: false
        property var onToggle: () => {}

        width: 130
        height: 44
        radius: Theme.radius
        color: active ? Theme.accent : Theme.color0

        Column {
            anchors.centerIn: parent
            spacing: 2

            Row {
                spacing: 4
                Text { text: icon; font.pixelSize: 12 }
                Text { text: label; color: active ? Theme.background : Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
            }

            Text {
                text: sublabel
                color: active ? Theme.background : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                visible: sublabel !== ""
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: onToggle()
        }
    }
}
