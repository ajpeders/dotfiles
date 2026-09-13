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
