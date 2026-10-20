local d = require("config.defaults")

local mod = d.mainMod

-- ====== Apps ======
hl.bind(mod .. " + Return",    hl.dsp.exec_cmd(d.terminal))
hl.bind(mod .. " + Q",         hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mod .. " + E",         hl.dsp.exec_cmd(d.browser))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(d.terminal .. " btop"))
hl.bind(mod .. " + Space",     hl.dsp.exec_cmd("jetshell ipc call launcher toggle"))
-- macOS-style copy: forward CTRL+C to the focused window. Kitty maps plain
-- ctrl+c to copy_or_interrupt, so it copies a selection there and still sends
-- SIGINT when there is none.
hl.bind(mod .. " + C",         hl.dsp.send_shortcut({ mods = "CTRL", key = "C", window = "activewindow" }))
hl.bind(mod .. " + V",         hl.dsp.send_shortcut({ mods = "CTRL", key = "V", window = "activewindow" }))
-- Clipboard history picker (JetShell panel over cliphist). Kept off Super+V so
-- the macOS-style Ctrl+V passthrough above stays available for plain pasting.
hl.bind(mod .. " + CTRL + V", hl.dsp.exec_cmd("jetshell ipc call clipboard toggle"))
hl.bind(mod .. " + J",         hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + M",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))

-- ====== Quickshell ======
-- Only the launcher and notification center are wired up so far. Clipboard
-- history, settings, control-center, session/power and caffeine had no
-- Quickshell equivalent when Noctalia was removed -- see ROADMAP.md.
hl.bind(mod .. " + N",     hl.dsp.exec_cmd("jetshell ipc call notifications toggle"))
-- Cycles white -> black -> red; kitty follows via sync-kitty-theme.sh.
hl.bind(mod .. " + T",     hl.dsp.exec_cmd("jetshell ipc call theme cycle"))
hl.bind(mod .. " + L",     hl.dsp.exec_cmd("loginctl lock-session"))

-- ====== Brightness (laptop) ======
-- SUPER+B opens a submap: Up/Down or +/- = screen, Left/Right = keyboard
-- backlight, Esc/Enter/B exits. SUPER+SHIFT+K cycles up only (0→20→40→60→80→100→0).
local kbd = "brightnessctl --device=kbd_backlight set"
hl.define_submap("brightness", function()
    hl.bind("up",    hl.dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true })
    hl.bind("down",  hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })
    hl.bind("equal", hl.dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true })
    hl.bind("minus", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })
    hl.bind("right", hl.dsp.exec_cmd(kbd .. " 10%+"), { repeating = true })
    hl.bind("left",  hl.dsp.exec_cmd(kbd .. " 10%-"), { repeating = true })
    hl.bind("escape",       hl.dsp.submap("reset"))
    hl.bind("Return",       hl.dsp.submap("reset"))
    hl.bind("b",            hl.dsp.submap("reset"))
    hl.bind(mod .. " + b",  hl.dsp.submap("reset"))
end)
hl.bind(mod .. " + B", hl.dsp.submap("brightness"))
hl.bind(mod .. " + SHIFT + K", hl.dsp.exec_cmd("~/.config/hypr/scripts/kbd-backlight-cycle.sh"))

-- ====== Screenshots & recording ======
-- Screenshots and recording live in scripts so they can notify, annotate,
-- and stay silent when a region grab is cancelled. See HOWTO.md.
local shot = "~/.config/hypr/scripts/screenshot.sh"
local rec  = "~/.config/hypr/scripts/screen-record.sh"
hl.bind(mod .. " + P",          hl.dsp.exec_cmd(shot .. " full"))
hl.bind(mod .. " + SHIFT + P",  hl.dsp.exec_cmd(shot .. " region"))
hl.bind(mod .. " + CTRL + P",   hl.dsp.exec_cmd(shot .. " copy"))
hl.bind(mod .. " + ALT + P",    hl.dsp.exec_cmd(shot .. " window"))
hl.bind(mod .. " + SHIFT + S",  hl.dsp.exec_cmd(shot .. " annotate"))
hl.bind(mod .. " + SHIFT + R",  hl.dsp.exec_cmd(rec .. " toggle region"))
hl.bind(mod .. " + ALT + R",    hl.dsp.exec_cmd(rec .. " toggle focused"))

-- ====== Dictation ======
-- Offline speech-to-text (nerd-dictation + VOSK). Toggle: first press starts
-- recording, second press stops and types. See scripts/nerd-dictation-toggle.sh.
hl.bind(mod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/nerd-dictation-toggle.sh"))

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
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("sh -c 'wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ && jetshell ipc call volume display'"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("sh -c 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && jetshell ipc call volume display'"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("sh -c 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && jetshell ipc call volume display'"),       { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),      { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"),                             { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"),                             { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd(kbd .. " 10%+"),                                      { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(kbd .. " 10%-"),                                      { locked = true, repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                                    { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"),                              { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                              { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                                { locked = true })
