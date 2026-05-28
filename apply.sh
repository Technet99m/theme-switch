#!/usr/bin/env bash
#  _   _
# | |_| |__   ___ _ __ ___   ___        __ _ _ __  _ __ | |_   _
# | __| '_ \ / _ \ '_ ` _ \ / _ \_____ / _` | '_ \| '_ \| | | | |
# | |_| | | |  __/ | | | | |  __/_____| (_| | |_) | |_) | | |_| |
#  \__|_| |_|\___|_| |_| |_|\___|      \__,_| .__/| .__/|_|\__, |
#                                            |_|   |_|      |___/
#
# Central theme apply script.
# Usage:
#   apply.sh <path/to/theme.sh>   — apply a specific theme
#   apply.sh                      — re-apply the last used theme
#
# Applies the theme's colors to:
#   - Hyprland window borders  (hypr/colors.lua or legacy hypr/colors.conf + hyprctl reload)
#   - Hyprlock                 (reads colors.conf on launch, no action needed)
#   - Swaync                   (swaync/colors.css + swaync-client -rs)
#   - Wlogout power menu       (wlogout/colors.css — reads fresh on each launch)
#   - Rofi launcher            (rofi/colors.rasi — reads fresh on each launch)
#   - Wallpaper                (swww direct — bypasses matugen to keep theme colors)
#   - Kitty terminal           (kitty/colors-theme.conf + live reload via remote control)
# Then saves the active theme and launches waybar via launch.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_THEME_FILE="$HOME/.config/tc99m/current-theme"

# -------------------------------------------------------
# Resolve theme file
# -------------------------------------------------------
if [ -n "$1" ] && [ -f "$1" ]; then
    config_sh="$1"
elif [ -f "$CURRENT_THEME_FILE" ]; then
    config_sh=$(cat "$CURRENT_THEME_FILE")
fi

if [ -z "$config_sh" ] || [ ! -f "$config_sh" ]; then
    echo ":: apply: no theme file found — pass a path or set $CURRENT_THEME_FILE"
    exit 0
fi

source "$config_sh"

# accent defaults to foreground if not set
accent_hex="${accent_hex:-$foreground_hex}"

if [ -z "$background_hex" ] || [ -z "$foreground_hex" ]; then
    echo ":: apply: background_hex / foreground_hex not set in $config_sh — skipping color sync"
    exit 0
fi

# Derive waybar theme folder from theme filename (glass-purple.sh → glass-purple)
theme_id=$(basename "$config_sh" .sh)

echo ":: Applying theme: $theme_name ($theme_id)"
echo "   background: #$background_hex"
echo "   foreground: #$foreground_hex"
echo "   accent:     #$accent_hex"

# -------------------------------------------------------
# Update Hyprland colors.
# Newer hypr-dots uses Lua (colors.lua); older configs used colors.conf.
# Update whichever files exist so both layouts keep working.
# -------------------------------------------------------
COLORS_LUA="$HOME/.config/hypr/colors.lua"
COLORS_CONF="$HOME/.config/hypr/colors.conf"

_upsert_hypr_lua() {
    local var="$1" hex="$2"
    if grep -q "^[[:space:]]*$var = \"rgba" "$COLORS_LUA"; then
        sed -i "s/^[[:space:]]*$var = \"rgba([0-9a-fA-F]*ff)\",/    $var = \"rgba(${hex}ff)\",/" "$COLORS_LUA"
    else
        sed -i "/^}/i\    $var = \"rgba(${hex}ff)\"," "$COLORS_LUA"
    fi
}

_upsert_hypr_conf() {
    local var="$1" hex="$2"
    if grep -q "^\$$var = rgba" "$COLORS_CONF"; then
        sed -i "s/^\$$var = rgba([0-9a-fA-F]*)$/\$$var = rgba(${hex}ff)/" "$COLORS_CONF"
    else
        echo "\$$var = rgba(${hex}ff)" >> "$COLORS_CONF"
    fi
}

if [ -f "$COLORS_LUA" ]; then
    _upsert_hypr_lua background "$background_hex"
    _upsert_hypr_lua foreground "$foreground_hex"
    _upsert_hypr_lua accent     "$accent_hex"
fi

if [ -f "$COLORS_CONF" ]; then
    _upsert_hypr_conf background "$background_hex"
    _upsert_hypr_conf foreground "$foreground_hex"
    _upsert_hypr_conf accent     "$accent_hex"
fi

if [ ! -f "$COLORS_LUA" ] && [ ! -f "$COLORS_CONF" ]; then
    mkdir -p "$HOME/.config/hypr"
    cat > "$COLORS_LUA" <<EOF
return {
    background = \"rgba(${background_hex}ff)\",
    foreground = \"rgba(${foreground_hex}ff)\",
    accent = \"rgba(${accent_hex}ff)\",
}
EOF
fi

# Reload hyprland so window borders pick up the new colors
hyprctl reload

# -------------------------------------------------------
# Update swaync/colors.css  (@background, @foreground, @accent)
# -------------------------------------------------------
SWAYNC_COLORS="$HOME/.config/swaync/colors.css"

_upsert_css() {
    local file="$1" var="$2" hex="$3"
    if grep -q "@define-color $var " "$file"; then
        sed -i "s/@define-color $var #[0-9a-fA-F]*;/@define-color $var #${hex};/" "$file"
    else
        echo "@define-color $var #${hex};" >> "$file"
    fi
}

_upsert_css "$SWAYNC_COLORS" background "$background_hex"
_upsert_css "$SWAYNC_COLORS" foreground "$foreground_hex"
_upsert_css "$SWAYNC_COLORS" accent     "$accent_hex"

# Reload swaync CSS
swaync-client -rs

# -------------------------------------------------------
# Update wlogout/colors.css  (@background, @foreground, @accent)
# Wlogout reads its CSS fresh on each launch — no restart needed.
# -------------------------------------------------------
WLOGOUT_COLORS="$HOME/.config/wlogout/colors.css"

_upsert_css "$WLOGOUT_COLORS" background "$background_hex"
_upsert_css "$WLOGOUT_COLORS" foreground "$foreground_hex"
_upsert_css "$WLOGOUT_COLORS" accent     "$accent_hex"

# -------------------------------------------------------
# Update rofi/colors.rasi  (foreground, accent, background)
# Rofi reads its theme fresh on each launch — no restart needed.
# -------------------------------------------------------
ROFI_COLORS="$HOME/.config/rofi/colors.rasi"

sed -i "s/    foreground: #[0-9a-fA-F]*/    foreground: #${foreground_hex}/" "$ROFI_COLORS"
sed -i "s/    accent: #[0-9a-fA-F]*/    accent: #${accent_hex}/" "$ROFI_COLORS"
sed -i "s/    background: rgba([^)]*);/    background: ${rofi_background_rgba};/" "$ROFI_COLORS"

# -------------------------------------------------------
# Switch wallpaper if the theme specifies one.
# Calls swww directly — bypasses wallpaper.sh/matugen so
# our manual theme colors are not overwritten.
# Blur/cache regeneration runs in the background so
# waybar launches immediately.
# -------------------------------------------------------
if [ -n "$theme_wallpaper" ] && [ -f "$theme_wallpaper" ]; then
    echo ":: Switching wallpaper: $theme_wallpaper"
    CACHE_DIR="$HOME/.cache/ml4w/hyprland-dotfiles"
    BLUR=$(cat "$HOME/.config/ml4w/settings/blur.sh" 2>/dev/null || echo "50x30")

    swww img "$theme_wallpaper" \
        --transition-type any \
        --transition-duration 2 \
        --transition-fps 60

    echo "$theme_wallpaper" > "$CACHE_DIR/current_wallpaper"

    # Regenerate blurred/square/rasi cache in the background
    BLURRED_THEME="$CACHE_DIR/blurred_${theme_id}.png"
    (
        # Only rebuild the blur if missing or source wallpaper is newer than cache
        if [ ! -f "$BLURRED_THEME" ] || [ "$theme_wallpaper" -nt "$BLURRED_THEME" ]; then
            magick "$theme_wallpaper" -resize 75% "$BLURRED_THEME"
            [ "$BLUR" != "0x0" ] && \
                magick "$BLURRED_THEME" -blur "$BLUR" "$BLURRED_THEME"
        fi
        # Point the generic path to the active theme's cached blur
        ln -sf "$BLURRED_THEME" "$CACHE_DIR/blurred_wallpaper.png"
        echo "* { current-image: url(\"$CACHE_DIR/blurred_wallpaper.png\", height); }" \
            > "$CACHE_DIR/current_wallpaper.rasi"
        magick "$theme_wallpaper" -gravity Center -extent 1:1 "$CACHE_DIR/square_wallpaper.png"
    ) &
fi

# -------------------------------------------------------
# Update kitty/colors-theme.conf (accent overrides)
# Kitty reads this on each new window open.
# -------------------------------------------------------
KITTY_THEME="$HOME/.config/kitty/colors-theme.conf"

cat > "$KITTY_THEME" << EOF
# Theme accent colors — managed by apply.sh, do not edit manually
cursor                #${accent_hex}
cursor_text_color     #${background_hex}
url_color             #${accent_hex}
selection_foreground  #${background_hex}
selection_background  #${accent_hex}

# Directories and paths (color4 = blue slot used by ls/zsh)
color4                #${foreground_hex}
color12               #${foreground_hex}
EOF

# Reload all running kitty instances
for sock in /tmp/kitty-[0-9]*; do
    [ -S "$sock" ] && kitty @ --to "unix:$sock" set-colors --all "$KITTY_THEME" 2>/dev/null || true
done

# -------------------------------------------------------
# Persist the active theme
# -------------------------------------------------------
mkdir -p "$(dirname "$CURRENT_THEME_FILE")"
echo "$config_sh" > "$CURRENT_THEME_FILE"

# -------------------------------------------------------
# Restart mybar
# -------------------------------------------------------
setsid "$HOME/dev/rice/mybar/launch.sh" >/dev/null 2>&1 &
