-- Personal keybinding overrides, loaded after Omarchy's defaults.
--
-- Omarchy binds a key by registering it; binding the same key again without
-- hl.unbind first leaves BOTH actions attached. So every override below that
-- lands on an Omarchy default unbinds it first.
--
-- See all current bindings with:  omarchy menu keybindings --print

-- ===========================================================================
-- Keys Omarchy leaves free -- no unbind needed
-- ===========================================================================

o.bind("SUPER + E", "Browser", { omarchy = "browser" })
o.bind("SUPER + N", "Notification history", "omarchy-shell notifications showHistory")
o.bind("SUPER + SHIFT + R", "Restart Omarchy shell", "omarchy restart shell")

-- True fullscreen. Note the old config had these swapped relative to Omarchy:
-- SUPER+M was `fullscreen, 0` (real fullscreen) and SUPER+F was `fullscreen, 1`
-- (maximize). Omarchy puts real fullscreen on SUPER+F and maximize on
-- SUPER+ALT+F, so SUPER+M below duplicates SUPER+F. To get the old split back,
-- uncomment the SUPER+F override too.
o.bind("SUPER + M", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- hl.unbind("SUPER + F")
-- o.bind("SUPER + F", "Full width", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- ===========================================================================
-- Control centre submap (SUPER + A)
-- ===========================================================================
-- Noctalia had one control-centre panel; Omarchy splits it into separate
-- panels on SUPER+CTRL+A/W/B/P. This gathers them behind one leader key.
-- Omarchy's own SUPER+CTRL+* bindings are left untouched.

hl.define_submap("control", function()
  o.bind("A", "Audio", "omarchy-shell shell toggle omarchy.audio")
  o.bind("W", "Network", "omarchy-shell shell toggle omarchy.network")
  o.bind("B", "Bluetooth", "omarchy-shell shell toggle omarchy.bluetooth")
  o.bind("P", "Power", "omarchy-shell shell toggle omarchy.power")

  o.bind("ESCAPE", "Exit control submap", hl.dsp.submap("reset"))
  o.bind("RETURN", "Exit control submap", hl.dsp.submap("reset"))
end)

o.bind("SUPER + A", "Control centre", hl.dsp.submap("control"))

-- ===========================================================================
-- Brightness submap (SUPER + B)
-- ===========================================================================
-- Up/Down or +/- = screen, Left/Right = keyboard backlight, Esc/Enter exits.
-- Omarchy also covers all of this directly: F1/F2 for screen (ALT for fine
-- steps) and SHIFT+F1/F2 for the keyboard. This is the old modal kept on top.

hl.define_submap("brightness", function()
  o.bind("UP", "Brightness up", "omarchy-brightness-display +5%", { repeating = true })
  o.bind("DOWN", "Brightness down", "omarchy-brightness-display 5%-", { repeating = true })
  o.bind("code:21", "Brightness up", "omarchy-brightness-display +5%", { repeating = true })
  o.bind("code:20", "Brightness down", "omarchy-brightness-display 5%-", { repeating = true })

  o.bind("RIGHT", "Keyboard brightness up", "omarchy-brightness-keyboard up", { repeating = true })
  o.bind("LEFT", "Keyboard brightness down", "omarchy-brightness-keyboard down", { repeating = true })

  o.bind("ESCAPE", "Exit brightness submap", hl.dsp.submap("reset"))
  o.bind("RETURN", "Exit brightness submap", hl.dsp.submap("reset"))
  o.bind("B", "Exit brightness submap", hl.dsp.submap("reset"))
end)

o.bind("SUPER + B", "Brightness", hl.dsp.submap("brightness"))

-- ===========================================================================
-- Overrides of Omarchy defaults -- each costs the feature named in the comment
-- ===========================================================================

-- was: Toggle workspace layout
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock system", "omarchy-system-lock")

-- was: Pop window out (float & pin). Still on SUPER+ESCAPE as well.
hl.unbind("SUPER + O")
o.bind("SUPER + O", "System menu", "omarchy-menu toggle system")

-- was: Browser (still on SUPER+E above and SUPER+SHIFT+RETURN)
hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + B", "btop", { tui = "btop" })

-- was: Dismiss last notification (dismiss-all stays on SUPER+SHIFT+comma)
hl.unbind("SUPER + comma")
o.bind("SUPER + comma", "Omarchy menu", "omarchy-menu toggle")

-- was: Next workspace (still on SUPER+SHIFT+TAB / SUPER+CTRL+TAB).
-- Only meaningful once an external display is attached.
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Focus next monitor", hl.dsp.focus({ monitor = "+1" }))

-- Screenshots. Omarchy's own PRINT and SUPER+F10/F11/F12 stay bound.
-- was: Pseudo window
hl.unbind("SUPER + P")
o.bind("SUPER + P", "Screenshot", "omarchy-capture-screenshot fullscreen")
-- was: Google Photos web app
hl.unbind("SUPER + SHIFT + P")
o.bind("SUPER + SHIFT + P", "Screenshot region", "omarchy-capture-screenshot region")
-- was: Power panel (still reachable via SUPER+A -> p, and SUPER+ESCAPE)
hl.unbind("SUPER + CTRL + P")
o.bind("SUPER + CTRL + P", "Screenshot region to clipboard", "omarchy-capture-screenshot region copy")

-- was: Keybindings menu (still available as `omarchy menu keybindings --print`)
hl.unbind("SUPER + K")
o.bind("SUPER + K", "Keyboard backlight cycle", "omarchy-brightness-keyboard cycle")

-- was: ChatGPT web app. Omarchy's equivalent is SUPER+CTRL+I.
hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + SHIFT + A", "Toggle keep-awake", "omarchy-toggle-idle toggle")

-- Scratchpad on the old magic-workspace keys. Omarchy's SUPER+S / SUPER+grave
-- and SUPER+ALT+S stay bound; only the bare SUPER+=/- resize pair is replaced
-- (the ALT, CTRL and SHIFT resize variants are untouched).
-- was: Shrink window left
hl.unbind("SUPER + code:21")
o.bind("SUPER + code:21", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))
-- was: Expand window left
hl.unbind("SUPER + code:20")
o.bind("SUPER + code:20", "Move window to scratchpad",
  hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Resize with SUPER+CTRL+arrows. Costs grouped-window focus on LEFT/RIGHT,
-- which is still on SUPER+ALT+TAB / SUPER+SHIFT+ALT+TAB.
hl.unbind("SUPER + CTRL + LEFT")
hl.unbind("SUPER + CTRL + RIGHT")
o.bind("SUPER + CTRL + LEFT", "Resize window left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
o.bind("SUPER + CTRL + RIGHT", "Resize window right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
o.bind("SUPER + CTRL + UP", "Resize window up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
o.bind("SUPER + CTRL + DOWN", "Resize window down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })
