hl.config({
    input = {
        kb_layout                   = "us",
        follow_mouse                = 1, -- 0|1|2|3
        sensitivity                 = 0,
        float_switch_override_focus = 2,

        -- Laptop touchpad (Apple trackpad on the Asahi MacBook). Ignored
        -- on machines without one.
        touchpad = {
            natural_scroll       = true,  -- macOS-style scroll direction
            tap_to_click         = true,
            disable_while_typing = true,
            clickfinger_behavior = true,  -- 1/2/3 fingers = left/right/middle (no button areas)
            scroll_factor        = 0.5,
        },
    },

    -- Shorter swipe travel to complete a workspace switch (default 300)
    gestures = {
        workspace_swipe_distance = 150,
    },
})

-- ====== Touchpad Gestures ======
-- https://wiki.hyprland.org/Configuring/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({
    fingers   = 4,
    direction = "up",
    action    = function() hl.dispatch(hl.dsp.workspace.toggle_special("magic")) end,
})
