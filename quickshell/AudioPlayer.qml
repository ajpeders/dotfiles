pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: audioPlayer
    readonly property var player: Mpris.players.values.find(p => p.isPlaying)
                                 || Mpris.players.values[0] || null
    readonly property string title: player ? player.trackTitle : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property bool playing: player ? player.isPlaying : false
    property var freq: []

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
        onRunningChanged: if (!running) audioPlayer.freq = []
    }
}
