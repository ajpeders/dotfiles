hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- Hyprland runs with a bare PATH that has no ~/.local/bin (login shells add it), so
-- keybinds could not see launchers like `jetshell`. Prepend it, and drop any copies
-- already there: this file is re-read on every reload and env changes accumulate.
local local_bin = os.getenv("HOME") .. "/.local/bin"
local dirs = {}
for dir in os.getenv("PATH"):gmatch("[^:]+") do
    if dir ~= local_bin then dirs[#dirs + 1] = dir end
end
hl.env("PATH", local_bin .. ":" .. table.concat(dirs, ":"))
