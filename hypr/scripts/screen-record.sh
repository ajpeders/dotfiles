#!/usr/bin/env bash
# Toggle screen recording with gpu-screen-recorder (GPU/VAAPI encode, AMD).
#
#   screen-record.sh [toggle] [monitor|region|focused]
#   screen-record.sh start [monitor|region|focused]
#   screen-record.sh stop
#
# Records the focused monitor, a selected region, or the focused window, plus
# the default audio output, to ~/Videos/Screencasts/ (override with RECORD_DIR).
# State is a pidfile under XDG_RUNTIME_DIR; SIGINT is gpu-screen-recorder's
# "stop and save". Add a mic with:  -a default_output -a default_input .
set -euo pipefail


pidfile="${XDG_RUNTIME_DIR:-/tmp}/gpu-screen-recorder.pid"
outdir="${RECORD_DIR:-$HOME/Videos/Screencasts}"

notify() { # icon title body
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Screen recording" -i "$1" "$2" "$3" 2>/dev/null || true
}

osd() { # start|stop|error [argument]
    local js
    js="$(command -v jetshell 2>/dev/null || true)"
    [ -z "$js" ] && js="$HOME/.local/bin/jetshell"
    [ -x "$js" ] || return 0
    "$js" ipc call recording "$@" 2>/dev/null || true
}

running() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; }

stop_rec() {
    if running; then
        kill -INT "$(cat "$pidfile")"                 # stop and save
        rm -f "$pidfile"
        notify media-playback-stop "Recording stopped" "Saved to ${outdir##*/}/"
        osd stop
    else
        rm -f "$pidfile"                              # clear a stale pidfile
    fi
}

start_rec() {
    command -v gpu-screen-recorder >/dev/null 2>&1 || {
        notify dialog-error "Recording failed" "gpu-screen-recorder is not installed"
        exit 1
    }
    if running; then
        notify dialog-information "Recording already active" "Stop the current recording before starting another"
        return 0
    fi
    rm -f "$pidfile"
    mkdir -p "$outdir"
    local target="$1" label file geometry
    case "$target" in
        monitor)
            target="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true)"
            [ -n "$target" ] || target="screen"        # gpu-screen-recorder's first-monitor id
            label="${target} monitor"
            file="$outdir/$(date +'%Y-%m-%d-%H%M%S')_recording.mp4"
            ;;
        region)
            command -v slurp >/dev/null 2>&1 || {
                notify dialog-error "Recording failed" "slurp is not installed"
                exit 1
            }
            geometry="$(slurp -f '%wx%h+%x+%y')" || return 0
            [ -n "$geometry" ] || {
                notify dialog-error "Recording failed" "Could not read the selected region"
                exit 1
            }
            label="selected region"
            file="$outdir/$(date +'%Y-%m-%d-%H%M%S')_region_recording.mp4"
            target="$geometry"
            ;;
        focused)
            geometry="$(hyprctl activewindow -j 2>/dev/null | jq -r 'select(.at and .size) | "\(.size[0])x\(.size[1])+\(.at[0])+\(.at[1])"' 2>/dev/null || true)"
            [ -n "$geometry" ] || {
                notify dialog-error "Recording failed" "No focused window to record"
                exit 1
            }
            label="focused window"
            file="$outdir/$(date +'%Y-%m-%d-%H%M%S')_window_recording.mp4"
            target="$geometry"
            ;;
        *)
            echo "usage: ${0##*/} [toggle|start|stop] [monitor|region|focused]" >&2
            exit 2
            ;;
    esac

    local logfile="${XDG_RUNTIME_DIR:-/tmp}/gpu-screen-recorder.log"
    gpu-screen-recorder \
        -w "$target" \
        -c mp4 -k h264 -q very_high \
        -f 60 -a default_output -ac aac \
        -cursor yes \
        -o "$file" \
        >"$logfile" 2>&1 &
    echo $! > "$pidfile"
    sleep 0.3
    if ! running; then
        rm -f "$pidfile"
        local error
        error="$(tail -n 1 "$logfile" 2>/dev/null || echo 'gpu-screen-recorder exited')"
        notify dialog-error "Recording failed" "$error"
        osd error "$error"
        return 1
    fi
    notify media-record "Recording started" "${label} → ${outdir##*/}/${file##*/}"
    osd start "$label"
}

action="${1:-toggle}"
target="${2:-monitor}"
case "$target" in
    monitor|region|focused) ;;
    *) echo "usage: ${0##*/} [toggle|start|stop] [monitor|region|focused]" >&2; exit 2 ;;
esac
case "$action" in
    toggle) running && stop_rec || start_rec "$target" ;;
    start)  start_rec "$target" ;;
    stop)   stop_rec ;;
    *) echo "usage: ${0##*/} [toggle|start|stop] [monitor|region|focused]" >&2; exit 2 ;;
esac
