-- ====== Transparency ======
local translucent = {
    "^(kitty)$",
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

-- ====== Gaming (immediate tearing for lowest latency) ======
hl.window_rule({ match = { class = "^(cs2)$" },           immediate = true })
hl.window_rule({ match = { class = "^(steam_app_730)$" }, immediate = true })

-- ====== Workspace Rules ======
hl.workspace_rule({ workspace = "w[tv1-10]", gaps_out = 5, gaps_in = 3 })
hl.workspace_rule({ workspace = "f[1]",      gaps_out = 5, gaps_in = 3 })
