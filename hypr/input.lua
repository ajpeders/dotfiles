-- Personal input overrides. Loaded after Omarchy's defaults, so only the
-- settings that actually differ from them belong here.

hl.config({
  input = {
    touchpad = {
      -- Omarchy disables tap-to-click on Asahi because disable_while_typing
      -- alone doesn't stop stray taps. Personal preference is taps on; if
      -- the cursor starts jumping mid-sentence, set this back to false.
      tap_to_click = true,
      disable_while_typing = true,

      -- Slightly faster than Omarchy's 0.4.
      scroll_factor = 0.5,
    },
  },
})

-- Touchpad gestures. Omarchy ships none by default.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- 4-finger swipe up toggles the scratchpad. Omarchy's scratchpad is
-- `special:scratchpad` (SUPER + S), not the old Noctalia `special:magic`.
hl.gesture({
  fingers = 4,
  direction = "up",
  action = function() hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad")) end,
})

-- Shorter swipe travel to complete a workspace switch (Hyprland default 300).
hl.config({
  gestures = {
    workspace_swipe_distance = 150,
  },
})
