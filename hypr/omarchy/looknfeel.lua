-- Personal look'n'feel overrides, loaded after Omarchy's defaults.
-- Border colors deliberately not set here: they come from the active Omarchy
-- theme, so `omarchy theme set ...` keeps working.

hl.config({
  general = {
    -- Declared, not inherited, so both desktop stacks stay in step: these are
    -- the values hypr/config/variables.lua sets for Noctalia. Omarchy's
    -- defaults happen to agree on the gaps today (5/10) and differ on the
    -- border (2), but an `omarchy update` can move its defaults, and then the
    -- two stacks would drift apart silently.
    gaps_in     = 5,
    gaps_out    = 10,
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

-- OpenCode runs inside the terminal and sets this title while active. Give it
-- the same stronger translucency used for terminals on the Noctalia desktop.
hl.window_rule({
  match = { title = "^(OpenCode)$" },
  opacity = "0.94 0.88",
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
