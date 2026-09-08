-- Personal keybinding overrides, loaded after Omarchy's defaults.
--
-- Nothing is enabled here on purpose: Omarchy has a native equivalent for
-- every bind the old Noctalia config defined, and it's worth learning those
-- first. See them all with:  omarchy menu keybindings --print
--
-- ---------------------------------------------------------------------------
-- Old Noctalia bind        Omarchy equivalent            Note
-- ---------------------------------------------------------------------------
-- SUPER + SPACE launcher   SUPER + SPACE                 same key, Omarchy menu
-- SUPER + Q close          SUPER + Q (or SUPER + W)      same
-- SUPER + F fullscreen     SUPER + F                     same
-- SUPER + J toggle split   SUPER + J                     same
-- SUPER + RETURN terminal  SUPER + RETURN                same
-- SUPER + E browser        SUPER + SHIFT + B             SUPER + SHIFT + RETURN also
-- SUPER + SHIFT + F float  SUPER + T                     SUPER + SHIFT + F is file manager
-- SUPER + L lock           SUPER + CTRL + L              SUPER + L toggles layout
-- SUPER + O session menu   SUPER + ESCAPE                SUPER + O pops a window out
-- SUPER + V clipboard      SUPER + CTRL + V              SUPER + V is universal paste
-- SUPER + N notifications  SUPER + SHIFT + ALT + COMMA   history; SUPER + COMMA dismisses
-- SUPER + A control centre SUPER + CTRL + A audio, + P power, + W network, + B bluetooth
-- SUPER + comma settings   SUPER + CTRL + O              toggle menu
-- SUPER + SHIFT + B btop   SUPER + CTRL + T              Activity
-- SUPER + P screenshot     PRINT                         SUPER + F10/F11/F12 window/region/display
-- SUPER + TAB focus mon.   CTRL + ALT + TAB              SUPER + TAB is next workspace
-- SUPER + B brightness     F1 / F2                       ALT + F1/F2 for fine steps
-- SUPER + K kbd backlight  SHIFT + F1 / SHIFT + F2       SUPER + K opens the keybindings menu
-- SUPER + SHIFT + R restart shell   omarchy restart shell
-- SUPER + SHIFT/CTRL + A keep-awake SUPER + CTRL + I     toggle locking on idle
-- ---------------------------------------------------------------------------
--
-- If any of these fight your muscle memory, uncomment the matching block.
-- Each one unbinds Omarchy's default first, which is required -- binding a key
-- that is already bound without unbinding leaves both actions attached.

-- Browser back on SUPER + E (Omarchy leaves SUPER + E free, so no unbind needed).
-- o.bind("SUPER + E", "Browser", { launch = "chromium" })

-- Float toggle back on SUPER + SHIFT + F (default there: file manager).
-- hl.unbind("SUPER + SHIFT + F")
-- o.bind("SUPER + SHIFT + F", "Toggle floating", hl.dsp.window.toggle_floating())

-- Lock back on SUPER + L (default there: toggle workspace layout).
-- hl.unbind("SUPER + L")
-- o.bind("SUPER + L", "Lock system", "omarchy-system-lock")

-- Session menu back on SUPER + O (default there: pop window out).
-- hl.unbind("SUPER + O")
-- o.bind("SUPER + O", "System menu", "omarchy-menu system")

-- btop back on SUPER + SHIFT + B (default there: browser).
-- hl.unbind("SUPER + SHIFT + B")
-- o.bind("SUPER + SHIFT + B", "btop", { launch = "kitty -e btop" })

-- Focus next monitor on SUPER + TAB (default there: next workspace).
-- Only worth it once an external display is attached; this laptop has one panel.
-- hl.unbind("SUPER + TAB")
-- o.bind("SUPER + TAB", "Focus next monitor", hl.dsp.focus({ monitor = "+1" }))
