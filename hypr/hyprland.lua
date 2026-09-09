-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃                   Hyprland Configuration (Lua)              ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
-- One entry point for two desktop stacks. Hyprland always loads this
-- file, so the stack is chosen here at load time rather than by
-- swapping files per machine:
--
--   Omarchy present  -> Omarchy's bootstrap + defaults, then the personal
--                       overrides in hypr/{monitors,input,bindings,
--                       looknfeel,autostart}.lua (M1 Air, Asahi).
--   Omarchy absent   -> the Noctalia desktop from hypr/config/*.lua.
--
-- Same check scripts/install.sh uses (the `omarchy` package), expressed
-- as the path that package owns.

local omarchy_path = os.getenv("OMARCHY_PATH") or "/usr/share/omarchy"
local function omarchy_installed()
    local f = io.open(omarchy_path .. "/default/hypr/bootstrap.lua", "r")
    if f then f:close() return true end
    return false
end

if omarchy_installed() then
    -- ================= Omarchy stack =================
    -- Omarchy's bootstrap keeps path setup out of this user config.
    dofile(omarchy_path .. "/default/hypr/bootstrap.lua")

    -- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
    -- omarchy_default_bindings = false
    -- Or disable only bindings for Omarchy's preinstalled apps/web apps:
    -- omarchy_preinstalled_bindings = false

    require("default.hypr.omarchy")

    -- Personal overrides load after Omarchy's defaults so package updates
    -- can improve the defaults without rewriting these files.
    require("hypr.monitors")
    require("hypr.input")
    require("hypr.bindings")
    require("hypr.looknfeel")
    require("hypr.autostart")

    -- Toggle config flags dynamically.
    require("default.hypr.toggles")
    return
end

-- ================= Noctalia stack =================
-- Migrated from hyprland.conf (hyprlang). noctalia-colors.conf is still
-- generated as hyprlang by noctalia-shell and parsed by
-- config/noctalia_colors.lua.
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

-- Noctalia theme colors last so they override defaults (as before)
require("config.noctalia_colors")
