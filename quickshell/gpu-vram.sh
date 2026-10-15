#!/usr/bin/env bash
# One line per GPU: label|name|used bytes|total bytes. "unavailable" means no driver reading.
shopt -s nullglob
nvidia_cards=()
gpu_name() {
    local slot name
    slot=$(sed -n 's/^PCI_SLOT_NAME=//p' "$1/uevent" 2>/dev/null)
    name=$(lspci -s "$slot" 2>/dev/null)
    if [[ $name =~ \[([^][]+)\] ]]; then
        # Use the last bracketed model name, not the chip codename.
        name=${name##*\[}
        printf '%s' "${name%%\]*}"
    else
        printf '%s' "$2"
    fi
}
for device in /sys/class/drm/card[0-9]*/device; do
    card=${device%/device}
    card=${card##*/}
    case $(cat "$device/vendor" 2>/dev/null) in
        0x1002)
            if [[ -r $device/mem_info_vram_used && -r $device/mem_info_vram_total ]]; then
                read -r used < "$device/mem_info_vram_used"
                read -r total < "$device/mem_info_vram_total"
                printf 'AMD %s|%s|%s|%s\n' "$card" "$(gpu_name "$device" "AMD $card")" "$used" "$total"
            fi
            ;;
        0x10de) nvidia_cards+=("$card") ;;
    esac
done

if ((${#nvidia_cards[@]})); then
    if command -v nvidia-smi >/dev/null &&
       output=$(timeout 3s nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null); then
        while IFS=, read -r index name used total; do
            [[ $index =~ ^[[:space:]]*[0-9]+[[:space:]]*$ &&
               $used =~ ^[[:space:]]*[0-9]+[[:space:]]*$ &&
               $total =~ ^[[:space:]]*[0-9]+[[:space:]]*$ ]] || continue
            printf 'NVIDIA %s|%s|%s|%s\n' "$index" "${name## }" "$((used * 1048576))" "$((total * 1048576))"
        done <<< "$output"
    else
        for card in "${nvidia_cards[@]}"; do
            printf 'NVIDIA %s|%s|unavailable|\n' "$card" "$(gpu_name "/sys/class/drm/$card/device" "NVIDIA $card")"
        done
    fi
fi
