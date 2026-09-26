# dotfiles

Cross-platform dotfiles: Hyprland + Noctalia 5 on Arch, AeroSpace on macOS, shared shell and TUI configs. On Arch the repo *is* `~/.config`.

See [ARCHITECTURE](ARCHITECTURE.md) for how it fits together, [HOWTO](HOWTO.md) for tasks, [ROADMAP](ROADMAP.md) for what's next.

## Install

```bash
# Linux: clone into ~/.config, then one of
git clone ssh://git@git.thelunadog.com:2222/alex/dotfiles.git ~/.config
bash ~/.config/scripts/install.sh              # Arch desktop
bash ~/.config/scripts/install.sh --headless   # Arch, CLI + sshd only
bash ~/.config/scripts/install-debian.sh       # Debian / Raspberry Pi (headless)

# macOS
git clone ssh://git@git.thelunadog.com:2222/alex/dotfiles.git ~/dotfiles
bash ~/dotfiles/macos/install.sh
```

Then run `p10k configure`.

## Keep in sync

```bash
bash scripts/update.sh                # Arch: pull, packages, relink, reload
bash scripts/doctor.sh                # read-only health check
bash scripts/sync-private.sh user@host  # private files (wallpapers, ssh, rclone, wireguard, gh)
bash scripts/setup-llm.sh [base-url]  # optional: point opencode/claude-local at another LLM server
```

## Key bindings

Mac uses `Alt` where Linux uses `Super`.

| Hyprland | AeroSpace | Action |
|----------|-----------|--------|
| `Super + Return` | `Alt + Enter` | Terminal |
| `Super + Q` | `Alt + Q` | Close window |
| `Super + E` | `Alt + E` | Browser |
| `Super + Shift + B` | `Alt + B` | btop |
| `Super + F` | — | Maximize |
| `Super + M` | `Alt + F` | Fullscreen |
| `Super + Shift + F` | `Alt + Shift + F` | Float toggle |
| `Super + J` | `Alt + J` | Toggle split |
| `Super + 1-0` | `Alt + 1-0` | Switch workspace |
| `Super + Shift + 1-0` | `Alt + Shift + 1-0` | Move window to workspace |
| `Super + Tab` | `Alt + Tab` | Next monitor |
| `Super + arrows` | `Alt + arrows` | Focus |
| `Super + Shift + arrows` | `Alt + Shift + arrows` | Move window |
| `Super + Ctrl + arrows` | `Alt + Ctrl + arrows` | Resize |

Hyprland only: launcher `Space`, clipboard `V`, notifications `N`, settings `,`, control center `A`, lock `L`, session `O`, restart shell `Shift+R`, caffeine `Shift+A`, brightness submap `B`, keyboard backlight `K`, screenshots `P` / `Shift+P` / `Ctrl+P`, scratchpad `=` / `-`, exit `Shift+Q`. Full list: `hypr/config/keybinds.lua`.
