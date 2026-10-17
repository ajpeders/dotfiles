-- Autostart necessary processes (was exec-once)
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
    -- Import env first, then start the shell in the same shell so the unit never
    -- races the import. systemd supervises it (systemd/user/jetshell.service).
    hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE; systemctl --user start jetshell.service")
    -- Started after the env import so the watcher inherits WAYLAND_DISPLAY.
    hl.exec_cmd("systemctl --user start cliphist.service")
    hl.exec_cmd("systemctl --user start gnome-keyring-daemon.socket")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    -- Idle management (dim -> lock -> screen off; never suspends).
    -- Picks hypr/hypridle-ac.conf or hypr/hypridle-battery.conf and swaps live.
    hl.exec_cmd("~/.config/hypr/scripts/hypridle-power.sh")
end)
