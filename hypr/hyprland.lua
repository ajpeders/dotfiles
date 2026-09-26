-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃                   Hyprland Configuration (Lua)              ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
-- Migrated from hyprland.conf (hyprlang). Border colours come from
-- hypr/noctalia.lua, rendered by Noctalia 5's theme template (see the end).
--
-- Monitors are hand-written in config/monitors.lua, keyed by EDID
-- description rather than connector name so one file serves every
-- setup. monitors.conf (nwg-displays) is dead — see HOWTO.md.

require("config.environment")
require("config.variables")
require("config.decorations")
require("config.animations")
require("config.input")
require("config.autostart")
require("config.keybinds")
require("config.monitors")
require("config.windowrules")

-- ====== Primary monitor ======
-- Hyprland has no "primary" flag; the closest thing is which monitor
-- owns workspace 1 by default, since that's where the session lands on
-- login and where unassigned windows go. Keyed by desc: like the
-- monitor rules — on a machine without this panel the rule never
-- matches and workspace 1 falls back to the normal monitor order.
hl.workspace_rule({
    workspace = "1",
    monitor   = "desc:Samsung Electric Company LS27FG53x",
    default   = true,
})

-- ====== Workspace Names ======
hl.workspace_rule({ workspace = "6",  default_name = "dev" })
hl.workspace_rule({ workspace = "7",  default_name = "server" })
hl.workspace_rule({ workspace = "8",  default_name = "work" })
hl.workspace_rule({ workspace = "9",  default_name = "game" })
hl.workspace_rule({ workspace = "10", default_name = "config" })

-- For Noctalia Color templates
-- Noctalia's built-in "hyprland" template renders hypr/noctalia.lua (gitignored)
-- from the active palette. Loaded last so the border colours win. Guarded so a
-- fresh machine boots before Noctalia has rendered it once.
local ok, noctalia = pcall(function() return require("noctalia") end)
if ok and noctalia then noctalia.apply_theme() end
