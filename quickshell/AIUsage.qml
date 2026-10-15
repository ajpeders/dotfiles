pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: usage
    property var providers: ({})
    property string deepseekSpend: ""

    function metric(id, windowSeconds) {
        const entry = providers[id]
        if (!entry || entry.status !== "ready" || !Array.isArray(entry.metrics)) return null
        return entry.metrics.find(item => item.window_secs === windowSeconds) || null
    }

    function percent(id, windowSeconds) {
        const value = metric(id, windowSeconds)
        const percent = value && Number(value.percent)
        return Number.isFinite(percent) && percent >= 0 ? Math.min(100, Math.round(percent)) : -1
    }

    function reading(id, windowSeconds) {
        const value = percent(id, windowSeconds)
        return value >= 0 ? value + "%" : "--"
    }

    Process {
        id: probe
        command: ["ai-usagebar", "usage", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const report = JSON.parse(text)
                    if (!Array.isArray(report.entries)) throw new Error("Missing entries")
                    const next = {}
                    for (const entry of report.entries) {
                        if (entry.id === "anthropic" || entry.id === "openai")
                            next[entry.id] = entry
                    }
                    usage.providers = next
                } catch (e) {
                    usage.providers = ({})
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) usage.providers = ({})
        }
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: if (!probe.running) probe.running = true
    }

    Process {
        id: deepseekProbe
        command: ["bash", Quickshell.shellPath("deepseek-spend.sh")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: usage.deepseekSpend = text.trim()
        }
        onExited: (code, status) => {
            if (code !== 0) usage.deepseekSpend = ""
            // The OpenCode background service may not be up yet right after login, so
            // retry quickly until we get a reading, then fall back to a slow refresh.
            deepseekRefresh.interval = usage.deepseekSpend === "" ? 20000 : 300000
            deepseekRefresh.restart()
        }
    }

    Timer {
        id: deepseekRefresh
        interval: 300000
        onTriggered: if (!deepseekProbe.running) deepseekProbe.running = true
    }
}
