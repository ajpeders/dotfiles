--!nonstrict
-- DNS tile: names the active connection's resolver, opens the switcher panel.

local NAMES = {
  ["8.8.8.8"] = "Google", ["1.1.1.1"] = "Cloudflare", ["208.67.222.222"] = "OpenDNS",
  ["94.140.14.14"] = "AdGuard", ["9.9.9.9"] = "Quad9",
}
-- The switcher's own custom slots ("Name = ip [ip]") name non-public resolvers.
-- Stops at the first unset slot: getSetting logs a warning for each miss.
for i = 1, 5 do
  local slot = noctalia.getSetting(`plugin_settings.nightwatch75/dns-switcher.custom_{i}`)
  if slot == nil then break end
  local name, ip = tostring(slot or ""):match("^%s*(.-)%s*=%s*([%d%.]+)")
  if name and name ~= "" then NAMES[ip] = name end
end

local CMD = [[nmcli -g ipv4.dns connection show "$(nmcli -g UUID,TYPE connection show --active | grep -v ':loopback$' | head -1 | cut -d: -f1)"]]

local label = "DNS"

local function render()
  shortcut.setLabel(label)
  shortcut.setIcon("world")
  shortcut.setActive(label ~= "ISP DNS")
  shortcut.setEnabled(true)
end

local function refresh()
  noctalia.runAsync(CMD, function(r)
    local ip = r.exitCode == 0 and r.stdout:match("[%d%.]+") or nil
    local tailnet = ip and ip:match("^100%.(%d+)%.")
    label = if not ip then "ISP DNS"
      elseif NAMES[ip] then NAMES[ip]
      elseif tailnet and tonumber(tailnet) >= 64 and tonumber(tailnet) < 128 then "Tailnet DNS"
      else "Custom DNS"
    render()
  end, 5000)
end

noctalia.setUpdateInterval(15000)
render()
refresh()

function update() refresh() end
function onClick() noctalia.togglePanel("nightwatch75/dns-switcher:panel") end
function onRightClick() refresh() end
