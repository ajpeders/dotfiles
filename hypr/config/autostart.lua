-- Autostart necessary processes (was exec-once)
hl.on("hyprland.start", function()
    -- Noctalia runs as a systemd user service (systemd/user/noctalia-shell.service)
    -- so SUPER+SHIFT+R can restart it and it comes back after a crash.
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP; systemctl --user start noctalia-shell.service")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- Idle management (dim -> lock -> screen off -> suspend on battery only).
    -- Picks hypr/hypridle-ac.conf or hypr/hypridle-battery.conf and swaps live.
    hl.exec_cmd("~/.config/hypr/scripts/hypridle-power.sh")
end)
