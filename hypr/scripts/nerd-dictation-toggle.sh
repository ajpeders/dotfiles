#!/usr/bin/env bash
# Toggle nerd-dictation (offline speech-to-text) on/off.
#
# First press starts recording; second press stops and types the result.
# Uses wtype to simulate keystrokes (Wayland) and the default parec recorder
# (pipewire-pulse). The VOSK model lives in ~/.config/nerd-dictation/model.
# State is shown as a JetShell OSD popup (DictationOsd.qml).
#
# The default Bluetooth mic in this setup reports a usable level only when its
# stream volume is boosted above 100% (200% brings it into normal speech range).
# We bump it on start and restore on stop so calls aren't permanently louder.
set -euo pipefail

# Hyprland's exec PATH does not include ~/.local/bin, so resolve jetshell
# explicitly and fall back to the well-known location.
osd() { # text
    local js
    js="$(command -v jetshell 2>/dev/null || true)"
    [ -z "$js" ] && js="$HOME/.local/bin/jetshell"
    [ -x "$js" ] || return 0
    "$js" ipc call dictation display "$1" 2>/dev/null || true
}

set_mic() { # volume (0.0–2.0)
    command -v wpctl >/dev/null 2>&1 || return 0
    wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "$1" >/dev/null 2>&1 || true
}

if pgrep -f "nerd-dictation begin" >/dev/null 2>&1; then
    nerd-dictation end
    set_mic 1.0
    osd "Dictation off"
else
    set_mic 2.0
    nerd-dictation begin --simulate-input-tool=WTYPE &
    osd "Dictation on"
fi
