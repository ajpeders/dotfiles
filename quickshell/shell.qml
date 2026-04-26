import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services
import Quickshell.Io

Quickshell.Application {
    id: app

    // Socket server for IPC from Hyprland keybinds
    SocketServer {
        id: ipcServer
        path: `/tmp/quickshell-${Sysinfo.username}.sock`
        splitParser: true

        onLineReceived: (line) => {
            const parts = line.trim().split(' ')
            const cmd = parts[0]
            const arg = parts[1]

            switch (cmd) {
                case 'volume':
                    handleVolumeCommand(arg)
                    break
                case 'brightness':
                    handleBrightnessCommand(arg)
                    break
            }
        }
    }

    // OSD states
    property var volumeOsdVisible: false
    property var brightnessOsdVisible: false

    // Load theme singleton
    Theme {}

    // Load bar on each screen
    Repeater {
        model: Quickshell.screens
        Bar {
            screen: modelData
        }
    }

    // OSD layers (shown/hidden by OSD components themselves)
    VolumeOsd {
        visible: app.volumeOsdVisible
    }
    BrightnessOsd {
        visible: app.brightnessOsdVisible
    }

    // Lazy-loaded panels (instantiated on demand)
    property var _mediaPopup: null
    property var _quickSettings: null
    property var _notificationCenter: null
    property var _systemMonitor: null
    property var _clipboardPopup: null

    function showMediaPopup() {
        if (!_mediaPopup) _mediaPopup = Qt.createComponent("media/MediaPopup.qml")
    }

    function showQuickSettings() {
        if (!_quickSettings) _quickSettings = Qt.createComponent("quicksettings/QuickSettings.qml")
    }

    function showNotificationCenter() {
        if (!_notificationCenter) _notificationCenter = Qt.createComponent("notifications/NotificationCenter.qml")
    }

    function showSystemMonitor() {
        if (!_systemMonitor) _systemMonitor = Qt.createComponent("monitor/SystemMonitor.qml")
    }

    function showClipboardPopup() {
        if (!_clipboardPopup) _clipboardPopup = Qt.createComponent("launcher/ClipboardPopup.qml")
    }

    // IPC handlers
    function handleVolumeCommand(action) {
        // Volume logic handled by VolumeSlider.qml via PipeWire
        // This just triggers the OSD visibility
        volumeOsdVisible = false
        volumeOsdVisible = true
        volumeOsdTimer.restart()
    }

    function handleBrightnessCommand(action) {
        brightnessOsdVisible = false
        brightnessOsdVisible = true
        brightnessOsdTimer.restart()
    }

    Timer {
        id: volumeOsdTimer
        interval: 1500
        onTriggered: app.volumeOsdVisible = false
    }

    Timer {
        id: brightnessOsdTimer
        interval: 1500
        onTriggered: app.brightnessOsdVisible = false
    }
}
