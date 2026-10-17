pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: usage
    property var providers: ({})
    property string deepseekBalance: ""
    property var hiddenProviders: ({})

    // One entry per vendor ai-usagebar reports usable data for, sorted by
    // display name so the bar and panel keep a stable order.
    readonly property var providerList: Object.keys(providers).map(id => providers[id])
        .sort((a, b) => String(a.display_name).localeCompare(String(b.display_name)))

    // Brand marks vendored under icons/ (see icons/SOURCES.md); a vendor with no
    // mark still works, it just renders without a logo.
    readonly property var iconNames: ({
        "anthropic": "claude",
        "openai": "codex",
        "openrouter": "openrouter",
        "minimax": "minimax"
    })

    function iconName(id) {
        return iconNames[id] || ""
    }

    // Whether a provider's indicator should appear in the bar. The panel's
    // toggles write here; DeepSeek only has an indicator once a balance lands.
    function shown(id) {
        if (hiddenProviders[id]) return false
        return id === "deepseek" ? deepseekBalance !== "" : true
    }

    function setShown(id, value) {
        const next = Object.assign({}, hiddenProviders)
        if (value) delete next[id]
        else next[id] = true
        hiddenProviders = next
        const ids = Object.keys(next)
        savedHidden.setText(ids.length ? ids.join("\n") + "\n" : "")
    }

    function toggleShown(id) {
        setShown(id, !!hiddenProviders[id])
    }

    function isFirst(id) {
        return providerList.length > 0 && providerList[0].id === id
    }

    // The shortest window is the vendor's current quota; the longest is the
    // slowest-moving one, drawn as the indicator's little bar.
    function primary(id) {
        const metrics = providers[id]?.metrics
        if (!Array.isArray(metrics) || !metrics.length) return null
        return metrics.reduce((a, b) => a.window_secs <= b.window_secs ? a : b)
    }

    function secondary(id) {
        const metrics = providers[id]?.metrics
        if (!Array.isArray(metrics) || metrics.length < 2) return null
        return metrics.reduce((a, b) => a.window_secs >= b.window_secs ? a : b)
    }

    function percentOf(metric) {
        const percent = metric && Number(metric.percent)
        return Number.isFinite(percent) && percent >= 0 ? Math.min(100, Math.round(percent)) : -1
    }

    function reading(id) {
        const metric = primary(id)
        return metric && metric.value ? String(metric.value) : "--"
    }

    // The balance moves as DeepSeek is spent, so it is polled on a shorter
    // cadence than the quota probe and re-read whenever the panel is opened.
    function refreshDeepseek() {
        if (!deepseekProbe.running) deepseekProbe.running = true
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
                        // DeepSeek is skipped: the bar shows its account balance
                        // from deepseek-balance.sh, not ai-usagebar's quota.
                        if (entry.id === "deepseek") continue
                        // Only vendors that actually have something to show, so
                        // the bar stays free of empty "--" entries.
                        if (entry.status !== "ready") continue
                        if (!Array.isArray(entry.metrics) || !entry.metrics.length) continue
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
        interval: 60000
        running: true
        repeat: true
        onTriggered: if (!probe.running) probe.running = true
    }

    Process {
        id: deepseekProbe
        command: ["bash", Quickshell.shellPath("deepseek-balance.sh")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: usage.deepseekBalance = text.trim()
        }
        onExited: (code, status) => {
            if (code !== 0) usage.deepseekBalance = ""
            // The network may not be up yet right after login, so
            // retry quickly until we get a reading, then keep the balance fresh.
            deepseekRefresh.interval = usage.deepseekBalance === "" ? 20000 : 60000
            deepseekRefresh.restart()
        }
    }

    Timer {
        id: deepseekRefresh
        interval: 60000
        onTriggered: if (!deepseekProbe.running) deepseekProbe.running = true
    }

    FileView {
        id: savedHidden
        path: Quickshell.statePath("ai-usage-hidden")
        printErrors: false // No saved choice on first launch.
        onLoaded: {
            const next = {}
            for (const id of text().split("\n")) {
                const value = id.trim()
                if (value) next[value] = true
            }
            usage.hiddenProviders = next
        }
    }
}
