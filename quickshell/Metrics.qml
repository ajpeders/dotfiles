pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: metrics
    property string cpu: "--"
    property var cpuCores: []
    property string loadAverage: "--"
    property string memory: "--"
    property string memoryUsed: "--"
    property var gpuCards: []
    property var lastCpuTimes: ({})

    IpcHandler {
        target: "metrics"
        function get(): string { return "CPU " + metrics.cpu + " RAM " + metrics.memory }
        function gpu(): string {
            return metrics.gpuCards.map(card => card.total > 0
                ? card.label + " " + card.used.toFixed(1) + "/" + card.total.toFixed(1) + " GB"
                : card.label + " unavailable").join(" | ")
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            // guest/guest_nice are already included in user/nice in /proc/stat.
            const nextTimes = {}
            const cores = []
            for (const line of text().split("\n")) {
                if (!/^cpu\d*\s/.test(line)) break
                const parts = line.trim().split(/\s+/)
                const name = parts[0]
                const values = parts.slice(1, 9).map(Number)
                const idle = values[3] + values[4]
                const total = values.reduce((sum, value) => sum + value, 0)
                const previous = metrics.lastCpuTimes[name]
                const percent = previous && total > previous.total
                    ? Math.round(100 * (1 - (idle - previous.idle) / (total - previous.total))) + "%"
                    : "--"
                if (name === "cpu") metrics.cpu = percent
                else cores.push({ label: "Core " + name.slice(3), usage: percent })
                nextTimes[name] = { idle, total }
            }
            metrics.lastCpuTimes = nextTimes
            metrics.cpuCores = cores
        }
    }

    FileView {
        id: loadavg
        path: "/proc/loadavg"
        onLoaded: metrics.loadAverage = text().trim().split(/\s+/).slice(0, 3).join(" / ")
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const content = text()
            const total = Number(content.match(/^MemTotal:\s+(\d+)/m)?.[1])
            const available = Number(content.match(/^MemAvailable:\s+(\d+)/m)?.[1])
            if (total && Number.isFinite(available)) {
                metrics.memoryUsed = ((total - available) / 1048576).toFixed(1) + "G"
                metrics.memory = ((total - available) / 1048576).toFixed(1) + "/" + (total / 1048576).toFixed(1) + " GB"
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            stat.reload()
            loadavg.reload()
            meminfo.reload()
        }
    }

    Process {
        id: gpuProbe
        command: ["bash", Quickshell.shellPath("gpu-vram.sh")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                metrics.gpuCards = text.trim().split("\n").filter(line => line.length > 0).map(line => {
                    const parts = line.split("|")
                    const label = parts[0].replace("AMD card", "A").replace("NVIDIA card", "N").replace("NVIDIA ", "N")
                    if (parts[2] === "unavailable") return { label, name: parts[1], used: -1, total: 0 }
                    return { label, name: parts[1], used: Number(parts[2]) / 1073741824, total: Number(parts[3]) / 1073741824 }
                })
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: if (!gpuProbe.running) gpuProbe.running = true
    }
}
