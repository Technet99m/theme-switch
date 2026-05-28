# theme-switch

A QuickShell-based theme picker for Hyprland rices. Displays a fullscreen overlay with animated wallpaper circles — click or use arrow keys to switch themes instantly.

![Theme picker showing circular wallpaper previews with colored rings]

## What it does

Applies a theme's color palette across the entire desktop in one shot:

- **Hyprland** — window border colors (`hypr/colors.lua`, with legacy `hypr/colors.conf` support, + `hyprctl reload`)
- **Hyprlock** — reads `colors.conf` on each launch, no action needed
- **Swaync** — notification center CSS (`swaync/colors.css` + live reload)
- **Wlogout** — power menu CSS (`wlogout/colors.css`, read fresh each launch)
- **Rofi** — launcher colors (`rofi/colors.rasi`, read fresh each launch)
- **Kitty** — terminal accent colors via remote control (live reload all instances)
- **Wallpaper** — switched via `swww` with a smooth transition

## Dependencies

- [QuickShell](https://quickshell.outfoxxed.me/) — shell UI framework (QML-based)
- [swww](https://github.com/LGS-Games/swww) — wallpaper daemon
- `hyprctl` — Hyprland IPC
- `swaync-client` — SwayNC notification center
- `kitty` with remote control enabled
- `imagemagick` (`magick`) — for blurred wallpaper cache generation

## Structure

```
theme-switch/
├── shell.qml          # QuickShell entry point — fullscreen picker UI
├── ThemeCircle.qml    # Individual theme circle widget with animations
├── load-themes.sh     # Outputs theme list for the QML process
├── apply.sh           # Applies a theme across all targets
└── themes/
    ├── glass-purple.sh
    ├── glass-green.sh
    ├── glass-red.sh
    └── glass-yellow.sh
```

## Adding a theme

Create a new `.sh` file in `themes/`:

```bash
#!/bin/bash
theme_name="My Theme"
background_hex="1e1e2e"        # no leading #
foreground_hex="cdd6f4"
accent_hex="89b4fa"            # optional, falls back to foreground
rofi_background_rgba="rgba(30, 30, 46, 0.7)"
theme_wallpaper="$HOME/wallpapers/my-wallpaper.jpg"
```

The theme is picked up automatically — no registration needed.

## Usage

### Launch the picker

```bash
quickshell -p /path/to/theme-switch
```

- **Click** a circle to apply that theme
- **Arrow keys** to navigate, **Enter** to apply
- **Escape** to close without changing

### Apply a theme directly

```bash
# Apply a specific theme
./apply.sh themes/glass-purple.sh

# Re-apply the last used theme
./apply.sh
```

The active theme is persisted to `~/.config/tc99m/current-theme`.

## How the picker works

1. `load-themes.sh` sources each theme file and outputs structured data
2. `shell.qml` parses the output, renders a circle per theme with entrance animations
3. On selection, an exit animation plays, then `apply.sh` is called with the chosen theme path
4. `apply.sh` updates each app's color config file and reloads/restarts as needed
