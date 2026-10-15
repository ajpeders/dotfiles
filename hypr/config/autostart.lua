-- Autostart necessary processes (was exec-once)
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
    hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
    hl.exec_cmd("systemctl --user start gnome-keyring-daemon.socket")
    hl.exec_cmd("quickshell --no-duplicate --daemonize")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    -- Idle management (dim -> lock -> screen off; never suspends).
    -- Picks hypr/hypridle-ac.conf or hypr/hypridle-battery.conf and swaps live.
    hl.exec_cmd("~/.config/hypr/scripts/hypridle-power.sh")
end)
