-- ====== Transparency ======
-- kitty is left out: its own background_opacity keeps text opaque.
local translucent = {
    "^(code|code-url-handler|Code|code-oss|VSCodium)$",
    "^(discord)$",
    "^(steam|Steam)$",
}
for _, class in ipairs(translucent) do
    hl.window_rule({ match = { class = class }, opacity = "0.94 0.88" })
end

-- ====== Floats ======
hl.window_rule({ match = { class = "^(org\\.pulseaudio\\.pavucontrol)$" }, float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true, size = "600 400", center = true })
hl.window_rule({ match = { title = "^(Save File|Open File)$" }, float = true })
hl.window_rule({ match = { class = "^(xdg-desktop-portal-(gtk|kde|hyprland).*)$" }, float = true })
hl.window_rule({ match = { class = "^(polkit-gnome-authentication-agent-1)$" }, float = true })
hl.window_rule({ match = { class = "^(LunaChat)$" }, float = false })

-- ====== Picture-in-Picture ======
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture)$" },

    float     = true,
    size      = "960 540",
    center    = true,
    opacity   = "1 override 1.0 override",
    no_blur   = true,
    no_shadow = true,
})

-- ====== Gaming (keep fullscreen when unfocused) ======
hl.window_rule({ match = { class = "^(steam_app_.*)$" }, suppress_event = "activateother" })
hl.window_rule({ match = { class = "^(gamescope)$" },    suppress_event = "activateother" })

-- ====== Idle inhibit (any fullscreen window) ======
-- hypridle only sees keyboard/mouse input and the Wayland idle-inhibit
-- protocol. XWayland games never speak that protocol, and gamepad input never
-- reaches the seat, so a controller session locks the screen after 5 min.
-- Block idle while any window is fullscreen: covers games and fullscreen video.
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- ====== Gaming (pin to workspace 9 "game") ======
-- Games always land on one workspace instead of wherever focus happened to
-- be, so alt-tabbing out and back is a workspace switch rather than a hunt.
-- Under gamescope the outer window's class is "gamescope", not steam_app_N,
-- so both need the rule. Append " silent" to open there without following.
hl.window_rule({ match = { class = "^(steam_app_.*)$" }, workspace = "9" })
hl.window_rule({ match = { class = "^(gamescope)$" },    workspace = "9" })

-- ====== Gaming (immediate tearing for lowest latency) ======
hl.window_rule({ match = { class = "^(cs2)$" },           immediate = true })
hl.window_rule({ match = { class = "^(steam_app_730)$" }, immediate = true })

-- ====== Workspace Rules ======
hl.workspace_rule({ workspace = "w[tv1-10]", gaps_out = 5, gaps_in = 3 })
hl.workspace_rule({ workspace = "f[1]",      gaps_out = 5, gaps_in = 3 })

-- ====== Noctalia ======
hl.window_rule({
    match = { class = "dev.noctalia.Noctalia" },
    float = true,
    size  = { 1080, 920 },
})
-- Blur Noctalia surfaces; disable Hyprland's layer animations so they don't
-- fight Noctalia's own.
hl.layer_rule({
    name  = "noctalia",
    match = { namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$" },
    no_anim      = true,
    ignore_alpha = 0.5,
    blur         = true,
    blur_popups  = true,
})
