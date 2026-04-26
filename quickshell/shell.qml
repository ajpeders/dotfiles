import Quickshell
import QtQuick
import "bar/" as Bar

PanelWindow {
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 34
    color: "#1a1a2e"

    Bar.Bar { }
}
