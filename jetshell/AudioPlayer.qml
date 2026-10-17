pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

Singleton {
    id: audioPlayer
    readonly property var player: Mpris.players.values.find(p => p.isPlaying)
                                 || Mpris.players.values.find(p => p.playbackState === MprisPlaybackState.Paused)
                                 || null
    property var metadataPlayer: null
    property string lastTitle: ""
    property string lastArtist: ""
    readonly property string title: player ? player.trackTitle || lastTitle : ""
    readonly property string artist: player ? player.trackArtist || lastArtist : ""
    readonly property bool playing: player ? player.isPlaying : false
    // Chromium uses INT64_MAX microseconds for an unknown/live duration.
    readonly property real duration: player && player.lengthSupported
        && Number.isFinite(player.length) && player.length > 0 && player.length < 9223372036854
        ? player.length : 0
    property var freq: []
    onPlayingChanged: { if (!playing) freq = [] }

    readonly property var outputStreams: Pipewire.nodes.values.filter(node => node.isStream && node.isSink && node.audio)
    readonly property var volumeNodes: outputStreams.filter(node => matchesPlayer(node))
    readonly property bool volumeSupported: volumeNodes.length > 0
        || (!!player && player.canControl && player.volumeSupported)
    readonly property real volume: volumeNodes.length > 0 ? volumeNodes[0].audio.volume
        : player && player.volumeSupported ? player.volume : 0

    function appName(value) {
        return String(value || "").toLowerCase().replace(/\.desktop$/, "").split("/").pop().split(".").pop()
    }

    function matchesPlayer(node) {
        if (!player) return false
        const names = [player.desktopEntry, player.identity,
            player.dbusName.replace(/^org\.mpris\.MediaPlayer2\./, "").split(".")[0]]
            .map(value => appName(value)).filter(value => value !== "")
        const props = node.properties || {}
        return [props["application.process.binary"], props["application.name"], props["application.desktop.id"]]
            .some(value => names.includes(appName(value)))
    }

    function setVolume(value) {
        const level = Math.max(0, Math.min(1, value))
        // Control the app, never the master sink. Chromium-based players can
        // expose MPRIS Volume without actually implementing volume writes.
        if (volumeNodes.length > 0) {
            for (const node of volumeNodes) node.audio.volume = level
        } else if (player && player.canControl && player.volumeSupported) {
            player.volume = level
        }
    }

    PwObjectTracker {
        objects: audioPlayer.outputStreams
    }

    function rememberMetadata() {
        if (metadataPlayer !== player) {
            metadataPlayer = player
            lastTitle = ""
            lastArtist = ""
        }
        if (player && player.trackTitle) lastTitle = player.trackTitle
        if (player && player.trackArtist) lastArtist = player.trackArtist
    }

    onPlayerChanged: rememberMetadata()

    Connections {
        target: audioPlayer.player
        function onTrackTitleChanged() { audioPlayer.rememberMetadata() }
        function onTrackArtistChanged() { audioPlayer.rememberMetadata() }
    }

    Process {
        command: ["python3", Quickshell.shellPath("audio-visualizer.py")]
        running: audioPlayer.playing
        stdout: SplitParser {
            onRead: data => {
                const values = data.trim().split(/\s+/).map(Number)
                if (audioPlayer.playing && values.length === 24 && values.every(v => Number.isFinite(v)))
                    audioPlayer.freq = values
            }
        }
    }
}
