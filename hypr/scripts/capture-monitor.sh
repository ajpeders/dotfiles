#!/usr/bin/env bash
# Print ready-to-paste hl.monitor() rules for whatever is plugged in now.
#
# Why this exists: config/monitors.lua matches panels by EDID
# description, and you can only read a panel's description while it's
# connected. So when you're at a desk whose monitors aren't in the
# config yet, run this there and paste the output in.
#
#   ~/.config/hypr/scripts/capture-monitor.sh
#
# The `desc:` key is built from make+model and deliberately omits the
# serial, so the rule matches any unit of that model rather than one
# specific physical panel. Add the serial back by hand if you own two
# of the same model and need to tell them apart.

set -euo pipefail

command -v jq >/dev/null || { echo "capture-monitor: jq is required" >&2; exit 1; }

echo "-- Captured $(date +%Y-%m-%d) on $(uname -n)"
echo "-- Positions are guesses: the first entry anchors at 0x0, adjust"
echo "-- the rest (auto-center-left/right/up/down) to match your desk."
echo

hyprctl -j monitors | jq -r '
  to_entries[] |
  .value as $m |
  "-- \($m.name): \($m.description)\n" +
  "hl.monitor({\n" +
  "    output   = \"desc:\($m.make) \($m.model)\",\n" +
  "    mode     = \"\($m.width)x\($m.height)@\($m.refreshRate | floor)\",\n" +
  "    position = \"" + (if .key == 0 then "auto" else "auto-center-right" end) + "\",\n" +
  "    scale    = \($m.scale),\n" +
  "})\n"
'

cat <<'EOF'
-- Reminder: a scale must yield integer logical sizes.
--   width / scale and height / scale must both be whole numbers,
--   or directional focus across monitors breaks.
--   e.g. 1920/0.8 = 2400 OK; 1920/0.83 = 2313.25 BROKEN.
--
-- Check a monitor's real max refresh before trusting the mode above:
-- some EDIDs under-report (the Samsung G53F advertises only 60Hz max).
-- Test a higher mode live:
--   hyprctl eval "hl.monitor({ output = 'desc:...', mode = '2560x1440@144', position = 'auto-right', scale = 1.0 })"
--
-- But a mode lighting up is NOT proof it holds. The G53F link-trains at
-- 200Hz and looks fine idle, then drops frames under load. Verify with a
-- fullscreen game before committing a mode to monitors.lua.
EOF
