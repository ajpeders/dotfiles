pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: notifications
    property bool centerOpen: false
    readonly property var trackedNotifications: server.trackedNotifications

    function toggle(): void {
        centerOpen = !centerOpen
    }

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true
        }
    }
}
