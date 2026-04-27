#!/usr/bin/env sh

set -eu

step="${VOLUME_STEP:-5%}"

usage() {
    printf 'Usage: %s up|down|mute\n' "${0##*/}" >&2
}

default_sink() {
    pactl info | awk -F': ' '/^Default Sink:/ { print $2; exit }'
}

running_sink() {
    pactl list short sinks | awk -F '\t' '$5 == "RUNNING" { print $2; exit }'
}

sink_for_first_input() {
    input_sink="$(pactl list short sink-inputs | awk -F '\t' 'NR == 1 { print $2; exit }')"

    if [ -n "$input_sink" ]; then
        pactl list short sinks | awk -F '\t' -v idx="$input_sink" '$1 == idx { print $2; exit }'
    fi
}

target_sink() {
    target="$(running_sink)"

    if [ -z "$target" ]; then
        target="$(sink_for_first_input)"
    fi

    if [ -z "$target" ]; then
        target="$(default_sink)"
    fi

    printf '%s\n' "$target"
}

action="${1:-}"
sink="$(target_sink)"

if [ -z "$sink" ]; then
    exit 1
fi

case "$action" in
    up)
        pactl set-default-sink "$sink"
        wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ "${step}+"
        ;;
    down)
        pactl set-default-sink "$sink"
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${step}-"
        ;;
    mute)
        pactl set-default-sink "$sink"
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    *)
        usage
        exit 2
        ;;
esac
