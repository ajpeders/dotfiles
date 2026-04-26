import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._Ipc
import Quickshell.Hyprland._GlobalShortcuts
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: root

    // Expose shell API to bar components via QtObject with closures
    property QtObject shellApi: QtObject {
        property var showMediaPopup: () => root.showMediaPopup()
        property var showQuickSettings: () => root.showQuickSettings()
        property var showNotificationCenter: () => root.showNotificationCenter()
        property var showSystemMonitor: () => root.showSystemMonitor()
        property var showClipboardPopup: () => root.showClipboardPopup()
        property var showLauncher: () => root.showLauncher()
    }

    // Socket server for IPC from Hyprland keybinds
    SocketServer {
        id: ipcServer
        path: "/tmp/quickshell-alex.sock"
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
                case 'launcher':
                    showLauncher()
                    break
                case 'clipboard':
                    showClipboardPopup()
                    break
            }
        }
    }

    // Load bar on each screen
    Repeater {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            screen: modelData
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 34
            layer: 1
            color: Theme.panelBg

            // Expose shell API to bar children
            property var shell: root

            // Bar must be loaded from file
            property var barComponent: barLoader.item
            Loader {
                id: barLoader
                source: "bar/Bar.qml"
                onLoaded: item.parentShell = barWindow
            }
        }
    }

    // OSD layers — lazily instantiated
    property var _volumeOsd: null
    property var _brightnessOsd: null

    // Lazy-loaded panels
    property var _mediaPopup: null
    property var _quickSettings: null
    property var _notificationCenter: null
    property var _systemMonitor: null
    property var _clipboardPopup: null
    property var _launcher: null

    function getMediaPopup() {
        if (!_mediaPopup) _mediaPopup = Qt.createComponent("media/MediaPopup.qml")
        return _mediaPopup
    }

    function getQuickSettings() {
        if (!_quickSettings) _quickSettings = Qt.createComponent("quicksettings/QuickSettings.qml")
        return _quickSettings
    }

    function getNotificationCenter() {
        if (!_notificationCenter) _notificationCenter = Qt.createComponent("notifications/NotificationCenter.qml")
        return _notificationCenter
    }

    function getSystemMonitor() {
        if (!_systemMonitor) _systemMonitor = Qt.createComponent("monitor/SystemMonitor.qml")
        return _systemMonitor
    }

    function getClipboardPopup() {
        if (!_clipboardPopup) _clipboardPopup = Qt.createComponent("launcher/ClipboardPopup.qml")
        return _clipboardPopup
    }

    function getLauncher() {
        if (!_launcher) _launcher = Qt.createComponent("launcher/Launcher.qml")
        return _launcher
    }

    function showMediaPopup() {
        const comp = getMediaPopup()
        if (comp.status === Component.Ready) {
            const win = comp.createObject(root)
            win.toggle()
        }
    }

    function showQuickSettings() {
        const comp = getQuickSettings()
        if (comp.status === Component.Ready) {
            const win = comp.createObject(root)
            win.toggle()
        }
    }

    function showNotificationCenter() {
        const comp = getNotificationCenter()
        if (comp.status === Component.Ready) {
            const win = comp.createObject(root)
            win.toggle()
        }
    }

    function showSystemMonitor() {
        const comp = getSystemMonitor()
        if (comp.status === Component.Ready) {
            const win = comp.createObject(root)
            win.visible = true
        }
    }

    function showClipboardPopup() {
        const comp = getClipboardPopup()
        if (comp.status === Component.Ready) {
            const win = comp.createObject(root)
            win.toggle()
        }
    }

    function showLauncher() {
        const comp = getLauncher()
        if (comp.status === Component.Ready) {
            const win = comp.createObject(root)
            win.visible = true
        }
    }

    function handleVolumeCommand(action) {
        if (action === "up") {
            Process.start("wpctl", ["set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"])
        } else if (action === "down") {
            Process.start("wpctl", ["set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"])
        } else if (action === "mute") {
            Process.start("wpctl", ["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        }
        getVolumeOsd().show()
    }

    function handleBrightnessCommand(action) {
        if (action === "up") {
            Process.start("brightnessctl", ["set", "5%+"])
        } else if (action === "down") {
            Process.start("brightnessctl", ["set", "5%-"])
        }
        getBrightnessOsd().show()
    }

    function getVolumeOsd() {
        if (!_volumeOsd) {
            const comp = Qt.createComponent("osd/VolumeOsd.qml")
            if (comp.status === Component.Ready) {
                _volumeOsd = comp.createObject(root)
            }
        }
        return _volumeOsd
    }

    function getBrightnessOsd() {
        if (!_brightnessOsd) {
            const comp = Qt.createComponent("osd/BrightnessOsd.qml")
            if (comp.status === Component.Ready) {
                _brightnessOsd = comp.createObject(root)
            }
        }
        return _brightnessOsd
    }
}
