pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

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
    property var freq: []

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
                if (values.length === 24 && values.every(v => Number.isFinite(v)))
                    audioPlayer.freq = values
            }
        }
    }
}
