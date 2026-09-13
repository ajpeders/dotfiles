-- Autostart necessary processes (was exec-once)
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
    hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
    hl.exec_cmd("systemctl --user start gnome-keyring-daemon.socket")
    -- Noctalia runs as a systemd user service (systemd/user/noctalia-shell.service)
    -- so SUPER+SHIFT+R can restart it and it comes back after a crash.
    hl.exec_cmd("systemctl --user start noctalia-shell.service")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    -- Idle management (dim -> lock -> screen off -> suspend on battery only).
    -- Picks hypr/hypridle-ac.conf or hypr/hypridle-battery.conf and swaps live.
    hl.exec_cmd("~/.config/hypr/scripts/hypridle-power.sh")
end)
