#!/usr/bin/env bash
# Outputs theme data for the QuickShell theme picker.
# Format:
#   HOME:/home/user
#   CURRENT:/path/to/current-theme.sh
#   THEME\t/path/to/theme.sh\tTheme Name\thexcolor\t/path/to/wallpaper.png
#   ...

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_DIR="$SCRIPT_DIR/themes"

echo "HOME:$HOME"

CURRENT=$(cat "$HOME/.config/tc99m/current-theme" 2>/dev/null || true)
echo "CURRENT:${CURRENT}"

for f in $(ls -1 "$THEMES_DIR/"*.sh 2>/dev/null | sort); do
    (
        source "$f" 2>/dev/null
        WP=$(eval echo "$theme_wallpaper")
        printf 'THEME\t%s\t%s\t%s\t%s\n' "$f" "$theme_name" "$foreground_hex" "$WP"
    )
done
