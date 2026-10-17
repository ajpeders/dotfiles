#!/usr/bin/env bash
# DNS presets for active ethernet/wifi NetworkManager connections.
#   dns.sh get           -> lan | router | cloudflare | custom
#   dns.sh set <preset>  -> apply to every active connection and reapply in place
set -euo pipefail

declare -A V4=([lan]="192.168.0.176 192.168.0.1" [router]="" [cloudflare]="1.1.1.1 1.0.0.1")
declare -A V6=([lan]="" [router]="" [cloudflare]="2606:4700:4700::1111 2606:4700:4700::1001")

connections() {
    nmcli -t -f NAME,TYPE,DEVICE con show --active \
        | awk -F: '$2 ~ /ethernet|wireless/ { print $1 ":" $3 }'
}

case ${1:-get} in
get)
    line=$(connections | head -n1)
    [ -n "$line" ] || { echo custom; exit; }
    # -g prints one line per field: dns (comma-separated), then ignore-auto-dns.
    { read -r dns; read -r ignore; } < <(nmcli -g ipv4.dns,ipv4.ignore-auto-dns con show "${line%%:*}")
    if [ -z "$dns" ] && [ "$ignore" = no ]; then echo router; exit; fi
    for preset in lan cloudflare; do
        [ "$dns" = "${V4[$preset]// /,}" ] && { echo "$preset"; exit; }
    done
    echo custom
    ;;
set)
    preset=${2:-none}
    [ -n "${V4[$preset]+x}" ] || { echo "unknown preset: $preset" >&2; exit 1; }
    ignore=yes; [ "$preset" = router ] && ignore=no
    connections | while IFS=: read -r name device; do
        nmcli con modify "$name" \
            ipv4.dns "${V4[$preset]}" ipv4.ignore-auto-dns "$ignore" \
            ipv6.dns "${V6[$preset]}" ipv6.ignore-auto-dns "$ignore"
        nmcli device reapply "$device"
    done
    ;;
*)
    echo "usage: dns.sh get | set <lan|router|cloudflare>" >&2
    exit 1
    ;;
esac
