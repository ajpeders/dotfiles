# HOWTO

## Change wallpaper

Noctalia manages wallpapers. Use IPC or the settings panel:

```bash
qs -c noctalia-shell ipc call wallpaper set ~/Pictures/Wallpapers/image.jpg ""
qs -c noctalia-shell ipc call wallpaper random ""
qs -c noctalia-shell ipc call settings openTab wallpaper
```

## Noctalia IPC

All Noctalia commands follow: `qs -c noctalia-shell ipc call <target> <function>`

```bash
# List all available commands
qs -c noctalia-shell ipc show

# Examples
qs -c noctalia-shell ipc call launcher toggle
qs -c noctalia-shell ipc call volume increase
qs -c noctalia-shell ipc call notifications toggleHistory
qs -c noctalia-shell ipc call settings toggle
qs -c noctalia-shell ipc call colorScheme set Kanagawa
```

## Restart Noctalia

```bash
pkill quickshell; qs -c noctalia-shell &
```

## Add a Hyprland keybind

Edit `~/.config/hypr/config/keybinds.conf`. Use `$ipc` variable for Noctalia commands:

```
bind = $mainMod, X, exec, $ipc <target> <function>
```

Then reload: `hyprctl reload`

## Fresh install on new machine

```bash
git clone <repo-url> ~/.config
cd ~/.config
bash install.sh
```

## Update existing install

```bash
cd ~/.config
bash update.sh
```

## Configure monitors

Use `nwg-displays` GUI tool. It writes to `~/.config/hypr/monitors.conf` — don't hand-edit that file.
