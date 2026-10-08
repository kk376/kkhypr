#!/usr/bin/env bash
# Sync GTK3, GTK4, Libadwaita, and Chromium browser themes with active Noctalia palette
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
GTK4_CSS="$CONFIG_DIR/gtk-4.0/noctalia.css"

# 1. Calculate nearest GNOME accent color from active Noctalia accent
if [ -f "$GTK4_CSS" ]; then
    nearest_accent=$(python3 - <<'PY' 2>/dev/null || true
import os, re, colorsys

css_path = os.path.expanduser("~/.config/gtk-4.0/noctalia.css")
if not os.path.isfile(css_path):
    raise SystemExit(1)

content = open(css_path).read()
m = re.search(r'@define-color\s+accent_color\s+#([0-9a-fA-F]{6});', content)
if not m:
    raise SystemExit(1)

hex_str = m.group(1)
r, g, b = (int(hex_str[i:i+2], 16)/255.0 for i in (0, 2, 4))
h, l, s = colorsys.rgb_to_hls(r, g, b)

gnome_accents = {
    'blue': 0.60,
    'teal': 0.50,
    'green': 0.33,
    'yellow': 0.14,
    'orange': 0.08,
    'red': 0.00,
    'pink': 0.92,
    'purple': 0.78,
}

if s < 0.2:
    print('slate')
else:
    best = min(gnome_accents.items(), key=lambda item: min(abs(h - item[1]), 1.0 - abs(h - item[1])))[0]
    print(best)
PY
)
    if [ -n "$nearest_accent" ]; then
        current_accent=$(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null | tr -d "'" || true)
        if [ "$current_accent" = "$nearest_accent" ]; then
            # Temporarily pulse to sibling accent so GSettings/dconf emits a guaranteed Changed signal
            temp_accent="blue"
            [ "$nearest_accent" = "blue" ] && temp_accent="teal"
            gsettings set org.gnome.desktop.interface accent-color "$temp_accent" 2>/dev/null || true
            sleep 0.05
        fi
        gsettings set org.gnome.desktop.interface accent-color "$nearest_accent" 2>/dev/null || true
    fi
fi

# 2. Pulse GTK theme with guaranteed debounce gap to broadcast DBus signal to Chrome, Brave, and GTK apps
sleep 0.05
current_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'" || true)
if [ "$current_theme" = "adw-gtk3-dark" ]; then
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3" 2>/dev/null || true
    sleep 0.05
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" 2>/dev/null || true
else
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" 2>/dev/null || true
    if [ -n "$current_theme" ]; then
        sleep 0.05
        gsettings set org.gnome.desktop.interface gtk-theme "$current_theme" 2>/dev/null || true
    fi
fi

# 3. Clean up headless background daemons with no visible windows so their next launch uses fresh state
if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    open_classes=$(hyprctl clients -j 2>/dev/null | jq -r '.[].class' 2>/dev/null || true)
    if ! echo "$open_classes" | grep -qi "clocks"; then
        pkill -f "gnome-clocks" 2>/dev/null || true
    fi
    if ! echo "$open_classes" | grep -qi "calculator"; then
        pkill -f "gnome-calculator" 2>/dev/null || true
    fi
fi
