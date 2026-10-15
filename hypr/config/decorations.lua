hl.config({
    decoration = {
        active_opacity     = 1.0,
        inactive_opacity   = 1.0,
        fullscreen_opacity = 1,
        rounding_power     = 2,
        rounding           = 0,
        dim_inactive       = true,
        dim_strength       = 0.15,

        blur = {
            enabled           = true,
            xray              = true,
            size              = 10,
            passes            = 3,
            new_optimizations = true,
            ignore_opacity    = false,
            popups            = true,
            vibrancy          = 0.25,
            vibrancy_darkness = 0.3,
            contrast          = 0.9,
            brightness        = 0.8,
        },

        shadow = {
            enabled      = true,
            range        = 9,
            render_power = 100,
            color        = 0xee1a1a1a, -- rgba(1a1a1aee)
        },
    },
})

-- Border and group colours. Noctalia rendered these from the wallpaper into
-- hypr/noctalia.lua; frozen here when Noctalia was removed. ROADMAP: have
-- Quickshell render them again.
hl.config({
    general = {
        col = {
            active_border   = "rgb(cdc7a5)",
            inactive_border = "rgb(141311)",
        },
    },
    group = {
        col = {
            border_active          = "rgb(cbc6b6)",
            border_inactive        = "rgb(141311)",
            border_locked_active   = "rgb(ffb4ab)",
            border_locked_inactive = "rgb(141311)",
        },
        groupbar = {
            col = {
                active          = "rgb(cbc6b6)",
                inactive        = "rgb(141311)",
                locked_active   = "rgb(ffb4ab)",
                locked_inactive = "rgb(141311)",
            },
            text_color                 = "rgb(323125)",
            text_color_inactive        = "rgb(e6e2dd)",
            text_color_locked_active   = "rgb(690005)",
            text_color_locked_inactive = "rgb(e6e2dd)",
        },
    },
})
