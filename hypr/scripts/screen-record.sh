#!/usr/bin/env bash
# Toggle screen recording with gpu-screen-recorder (GPU/VAAPI encode, AMD).
#
#   screen-record.sh        start if idle, stop-and-save if running
#   screen-record.sh start  start only
#   screen-record.sh stop   stop only (idempotent)
#
# Records the focused monitor and the default audio output to
# ~/Videos/Screencasts/<timestamp>_recording.mp4 (override with RECORD_DIR).
# State is a pidfile under XDG_RUNTIME_DIR; SIGINT is gpu-screen-recorder's
# "stop and save". Add a mic with:  -a default_output -a default_input .
set -euo pipefail

pidfile="${XDG_RUNTIME_DIR:-/tmp}/gpu-screen-recorder.pid"
outdir="${RECORD_DIR:-$HOME/Videos/Screencasts}"

notify() { # icon title body
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Screen recording" -i "$1" "$2" "$3" 2>/dev/null || true
}

running() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; }

stop_rec() {
    if running; then
        kill -INT "$(cat "$pidfile")"                 # stop and save
        rm -f "$pidfile"
        notify media-playback-stop "Recording stopped" "Saved to ${outdir##*/}/"
    else
        rm -f "$pidfile"                              # clear a stale pidfile
    fi
}

start_rec() {
    command -v gpu-screen-recorder >/dev/null 2>&1 || {
        notify dialog-error "Recording failed" "gpu-screen-recorder is not installed"
        exit 1
    }
    mkdir -p "$outdir"
    local monitor file
    monitor="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true)"
    [ -n "$monitor" ] || monitor="screen"             # gpu-screen-recorder's first-monitor id
    file="$outdir/$(date +'%Y-%m-%d-%H%M%S')_recording.mp4"

    gpu-screen-recorder \
        -w "$monitor" \
        -c mp4 -k h264 -q very_high \
        -f 60 -a default_output -ac aac \
        -cursor yes \
        -o "$file" \
        >/dev/null 2>&1 &
    echo $! > "$pidfile"
    notify media-record "Recording started" "${monitor} → ${outdir##*/}/${file##*/}"
}

case "${1:-toggle}" in
    toggle) running && stop_rec || start_rec ;;
    start)  start_rec ;;
    stop)   stop_rec ;;
    *) echo "usage: ${0##*/} [toggle|start|stop]" >&2; exit 2 ;;
esac