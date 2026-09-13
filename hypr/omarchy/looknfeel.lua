-- Personal look'n'feel overrides, loaded after Omarchy's defaults.
-- Border colors deliberately not set here: they come from the active Omarchy
-- theme, so `omarchy theme set ...` keeps working.

hl.config({
  general = {
    -- Omarchy default is 2. Carried over from the old Noctalia config.
    border_size = 3,
  },

  decoration = {
    -- Dim unfocused windows. Not an Omarchy default, but it was in the old
    -- config and it makes the focused window obvious on a single 13" display.
    dim_inactive = true,
    dim_strength = 0.15,
  },

  dwindle = {
    -- Omarchy defaults to force_split = 2, which makes new terminals split
    -- from the focused terminal. Restore Hyprland's automatic placement.
    force_split = 0,
  },
})

-- The old desktop config ran blur (size 10, passes 3) and shadows. Omarchy
-- disables both by default, which is the better trade on an M1 Air. Uncomment
-- to bring them back if you miss the look and can spare the battery.
-- hl.config({
--   decoration = {
--     blur = {
--       enabled = true,
--       size = 10,
--       passes = 3,
--       xray = true,
--       vibrancy = 0.25,
--     },
--     shadow = {
--       enabled = true,
--       range = 9,
--       render_power = 100,
--     },
--   },
-- })
