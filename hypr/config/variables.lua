hl.config({
    general = {
        gaps_in          = 5,
        gaps_out         = 10,
        border_size      = 3,
        resize_on_border = false,
        allow_tearing    = true,
        layout           = "dwindle",
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        vrr                     = 0,
    },

    debug = {
        vfr = true,
    },

    -- Multi-GPU (RX 9700 + Granite Ridge iGPU) crashes in
    -- CDRMRenderer::blit when rendering cursor on the secondary GPU.
    cursor = {
        no_hardware_cursors = true,
    },
})
