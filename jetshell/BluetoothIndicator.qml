import QtQuick
import Quickshell
import Quickshell.Bluetooth

Item {
    id: indicator
    required property var selection
    readonly property alias popupWindow: details
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values.filter(device => device.paired) : []
    readonly property int connectedCount: devices.filter(device => device.connected).length
    width: label.implicitWidth
    height: 30

    Text {
        id: label
        anchors.centerIn: parent
        text: !indicator.adapter ? "BT N/A" : !indicator.adapter.enabled ? "BT Off"
              : indicator.connectedCount > 0 ? "BT " + indicator.connectedCount : "BT On"
        color: Theme.foreground
        opacity: indicator.adapter && indicator.adapter.enabled ? 1 : 0.5
        font.family: Theme.fontFamily
        font.pixelSize: 20
        font.bold: false
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: indicator.selection.togglePanel("bluetooth")
    }

    PopupWindow {
        id: details
        anchor.item: indicator
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.FlipX | PopupAdjustment.SlideX
        anchor.margins.bottom: 0
        visible: indicator.selection.activePanel === "bluetooth"
        implicitWidth: 340
        implicitHeight: content.implicitHeight + 20
        color: Theme.background

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border.color: Theme.mode === "white" ? Theme.panelBorder : "#000000"
            border.width: 1

            Column {
                id: content
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 10
                width: parent.width - 20
                spacing: 8

                Text {
                    width: parent.width
                    text: "Bluetooth  ·  " + (indicator.adapter
                          ? BluetoothAdapterState.toString(indicator.adapter.state) : "No adapter")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: false
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    visible: !!indicator.adapter
                    color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)

                    Text {
                        anchors.centerIn: parent
                        text: indicator.adapter && indicator.adapter.enabled ? "Turn off" : "Turn on"
                        color: Theme.foreground
                        font.family: Theme.regularFontFamily
                        font.pixelSize: 16
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !!indicator.adapter
                                 && indicator.adapter.state !== BluetoothAdapterState.Enabling
                                 && indicator.adapter.state !== BluetoothAdapterState.Disabling
                        onClicked: indicator.adapter.enabled = !indicator.adapter.enabled
                    }
                }

                Text {
                    visible: indicator.devices.length === 0
                    text: "No paired devices"
                    color: Theme.foreground
                    font.family: Theme.regularFontFamily
                    font.pixelSize: 16
                }

                Repeater {
                    model: indicator.devices

                    Rectangle {
                        required property var modelData
                        width: content.width
                        height: 48
                        color: deviceMouse.containsMouse
                               ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
                               : "transparent"

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width

                            Text {
                                width: parent.width
                                text: modelData.name || modelData.address
                                elide: Text.ElideRight
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.bold: false
                            }
                            Text {
                                text: BluetoothDeviceState.toString(modelData.state)
                                color: Theme.foreground
                                font.family: Theme.regularFontFamily
                                font.pixelSize: 14
                            }
                        }

                        MouseArea {
                            id: deviceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: indicator.adapter && indicator.adapter.enabled
                                     && (modelData.state === BluetoothDeviceState.Connected
                                         || modelData.state === BluetoothDeviceState.Disconnected)
                            onClicked: modelData.connected = !modelData.connected
                        }
                    }
                }
            }
        }
    }
}
