local d = require("config.defaults")

local mod  = d.mainMod
local ipc  = "qs -c noctalia-shell ipc call"
local shot = "~/Pictures/Screenshots/$(date +'%Y-%m-%d-%H%M%S_screenshot.png')"

-- ====== Apps ======
hl.bind(mod .. " + Return",    hl.dsp.exec_cmd(d.terminal))
hl.bind(mod .. " + Q",         hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mod .. " + E",         hl.dsp.exec_cmd(d.browser))
hl.bind(mod .. " + B",         hl.dsp.exec_cmd(d.terminal .. " btop"))
hl.bind(mod .. " + Space",     hl.dsp.exec_cmd(ipc .. " launcher toggle"))
hl.bind(mod .. " + V",         hl.dsp.exec_cmd(ipc .. " launcher clipboard"))
hl.bind(mod .. " + J",         hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + M",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))

-- ====== Noctalia ======
hl.bind(mod .. " + N",     hl.dsp.exec_cmd(ipc .. " notifications toggleHistory"))
hl.bind(mod .. " + comma", hl.dsp.exec_cmd(ipc .. " settings toggle"))
hl.bind(mod .. " + A",     hl.dsp.exec_cmd(ipc .. " controlCenter toggle"))
hl.bind(mod .. " + L",     hl.dsp.exec_cmd(ipc .. " lockScreen lock"))
hl.bind(mod .. " + O",     hl.dsp.exec_cmd(ipc .. " sessionMenu toggle"))
-- Restart the shell (recovery after a crash, e.g. Bluetooth disconnect segfault)
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("systemctl --user restart noctalia-shell.service"))

-- ====== Screenshots ======
hl.bind(mod .. " + P",          hl.dsp.exec_cmd("grim " .. shot))
hl.bind(mod .. " + SHIFT + P",  hl.dsp.exec_cmd('grim -g "$(slurp)" ' .. shot))
hl.bind(mod .. " + CTRL + P",   hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))

-- ====== Monitor Focus (for gaming) ======
hl.bind(mod .. " + Tab", hl.dsp.focus({ monitor = "+1" }))

-- ====== Focus / Move / Resize ======
local dirs = { left = "left", right = "right", up = "up", down = "down" }
for key, dir in pairs(dirs) do
    hl.bind(mod .. " + " .. key,             hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ direction = dir }))
end
hl.bind(mod .. " + CTRL + left",  hl.dsp.window.resize({ x = -50, y = 0,   relative = true }))
hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 50,  y = 0,   relative = true }))
hl.bind(mod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -50, relative = true }))
hl.bind(mod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }))

-- ====== Workspaces ======
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i, on_current_monitor = true }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + equal", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + minus", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ====== Media Keys ======
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(ipc .. " volume increase"),      { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(ipc .. " volume decrease"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(ipc .. " volume muteOutput"),    { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(ipc .. " volume muteInput"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(ipc .. " brightness increase"),  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. " brightness decrease"),  { locked = true, repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd(ipc .. " media next"),           { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd(ipc .. " media playPause"),      { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd(ipc .. " media playPause"),      { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd(ipc .. " media previous"),       { locked = true })
